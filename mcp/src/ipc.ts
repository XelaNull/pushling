/**
 * IPC Client — Unix domain socket connection to the Pushling daemon.
 *
 * Communicates via NDJSON (newline-delimited JSON) over /tmp/pushling.sock.
 * Each request gets a UUID, and responses are matched by ID to support
 * multiple in-flight requests.
 *
 * Protocol: See docs/IPC-PROTOCOL.md for the full specification.
 */

import { createConnection, Socket } from "node:net";
import { randomUUID } from "node:crypto";

const SOCKET_PATH = "/tmp/pushling.sock";
const DEFAULT_TIMEOUT_MS = 5000;
const MAX_RECONNECT_ATTEMPTS = 3;
const RECONNECT_BACKOFF_MS = [1000, 2000, 4000];
const MAX_MESSAGE_SIZE = 65_536; // 64 KB

// ─── Types ───────────────────────────────────────────────────────────

/** A single event from the daemon's event buffer. */
export interface PendingEvent {
  seq: number;
  type: string;
  timestamp: string;
  data: Record<string, unknown>;
}

/** Response from the daemon to any IPC command. */
export interface IPCResponse {
  id: string;
  ok: boolean;
  data?: Record<string, unknown>;
  error?: string;
  code?: string;
  pending_events: PendingEvent[];
}

/** Creature state snapshot returned by the connect handshake. */
export interface CreatureSnapshot {
  name: string;
  stage: string;
  xp: number;
  personality: {
    energy: number;
    verbosity: number;
    focus: number;
    discipline: number;
    specialty: string;
  };
  emotions: {
    satisfaction: number;
    curiosity: number;
    contentment: number;
    energy: number;
  };
  speech: {
    max_chars: number;
    max_words: number;
    styles: string[];
  };
  tricks_known: number;
  streak_days: number;
}

/** Callback for pending events received with any response. */
export type EventCallback = (events: PendingEvent[]) => void;

/** Internal tracking for in-flight requests. */
interface PendingRequest {
  resolve: (response: IPCResponse) => void;
  reject: (error: Error) => void;
  timer: ReturnType<typeof setTimeout>;
}

// ─── DaemonClient ────────────────────────────────────────────────────

/**
 * Client for communicating with the Pushling daemon over a Unix domain socket.
 *
 * Usage:
 *   const client = new DaemonClient();
 *   await client.connect();
 *   const { sessionId, creature } = await client.startSession();
 *   const response = await client.send("sense", "self");
 *   await client.disconnect();
 */
export class DaemonClient {
  private socket: Socket | null = null;
  private connected = false;
  private connecting = false;
  private sessionId: string | null = null;
  private pendingRequests = new Map<string, PendingRequest>();
  private buffer = "";
  private reconnectAttempts = 0;
  private reconnectTimer: ReturnType<typeof setTimeout> | null = null;
  private timeoutMs: number;
  private eventCallback: EventCallback | null = null;

  constructor(options?: { timeoutMs?: number }) {
    this.timeoutMs = options?.timeoutMs ?? DEFAULT_TIMEOUT_MS;
  }

  /**
   * Register a callback for pending events.
   * Called whenever a response includes pending_events with at least one event.
   */
  onEvents(callback: EventCallback): void {
    this.eventCallback = callback;
  }

  /**
   * Connect to the daemon Unix socket.
   * Throws if the daemon is not running or the socket doesn't exist.
   */
  async connect(): Promise<void> {
    if (this.connected) return;
    if (this.connecting) {
      // Wait for the in-progress connection
      return new Promise((resolve, reject) => {
        const check = setInterval(() => {
          if (this.connected) {
            clearInterval(check);
            resolve();
          } else if (!this.connecting) {
            clearInterval(check);
            reject(new Error("Connection attempt failed"));
          }
        }, 50);
      });
    }

    this.connecting = true;

    return new Promise<void>((resolve, reject) => {
      this.socket = createConnection({ path: SOCKET_PATH });

      this.socket.on("connect", () => {
        this.connected = true;
        this.connecting = false;
        this.reconnectAttempts = 0;
        this.buffer = "";
        resolve();
      });

      this.socket.on("data", (data: Buffer) => {
        this.handleData(data.toString("utf-8"));
      });

      this.socket.on("error", (err: Error) => {
        if (!this.connected) {
          this.connecting = false;
          reject(
            new Error(
              `Cannot connect to Pushling daemon at ${SOCKET_PATH}: ${err.message}. ` +
                `Is Pushling.app running?`
            )
          );
        } else {
          this.handleDisconnect(err);
        }
      });

      this.socket.on("close", () => {
        if (this.connected) {
          this.handleDisconnect(new Error("Connection closed by daemon"));
        }
      });
    });
  }

  /**
   * Disconnect cleanly from the daemon.
   * Sends a disconnect command if a session is active, then closes the socket.
   */
  async disconnect(): Promise<void> {
    // Cancel any pending reconnect
    if (this.reconnectTimer) {
      clearTimeout(this.reconnectTimer);
      this.reconnectTimer = null;
    }

    if (!this.connected || !this.socket) {
      this.cleanup();
      return;
    }

    // Send session disconnect if we have an active session
    if (this.sessionId) {
      try {
        await this.send("disconnect", undefined, {
          session_id: this.sessionId,
        });
      } catch {
        // Best-effort disconnect — don't fail if daemon is unresponsive
      }
      this.sessionId = null;
    }

    this.cleanup();
  }

  /**
   * Send a command to the daemon and await the response.
   *
   * @param cmd     Command name (sense, move, express, etc.)
   * @param action  Sub-action (optional for session commands)
   * @param params  Additional parameters (optional)
   * @returns       The daemon's response
   */
  async send(
    cmd: string,
    action?: string,
    params?: Record<string, unknown>
  ): Promise<IPCResponse> {
    if (!this.connected || !this.socket) {
      throw new Error(
        "Not connected to Pushling daemon. Call connect() first, or ensure " +
          "Pushling.app is running."
      );
    }

    const id = randomUUID();
    const request: Record<string, unknown> = { id, cmd };
    if (action !== undefined && action !== "") {
      request.action = action;
    }
    if (params && Object.keys(params).length > 0) {
      request.params = params;
    }

    const message = JSON.stringify(request) + "\n";

    if (message.length > MAX_MESSAGE_SIZE) {
      throw new Error(
        `Message exceeds ${MAX_MESSAGE_SIZE} byte limit (${message.length} bytes). ` +
          `Reduce parameter size.`
      );
    }

    return new Promise<IPCResponse>((resolve, reject) => {
      const timer = setTimeout(() => {
        this.pendingRequests.delete(id);
        reject(
          new Error(
            `Command '${cmd}${action ? ":" + action : ""}' timed out after ${this.timeoutMs}ms. ` +
              `The daemon may be overloaded or unresponsive.`
          )
        );
      }, this.timeoutMs);

      this.pendingRequests.set(id, { resolve, reject, timer });

      this.socket!.write(message, (err) => {
        if (err) {
          clearTimeout(timer);
          this.pendingRequests.delete(id);
          reject(
            new Error(`Failed to send command '${cmd}': ${err.message}`)
          );
        }
      });
    });
  }

  /**
   * Start a session with the daemon.
   * Must be called after connect() and before sending tool commands.
   * Returns the session ID and initial creature state snapshot.
   */
  async startSession(): Promise<{
    sessionId: string;
    creature: CreatureSnapshot;
  }> {
    const response = await this.send("connect", undefined, {
      client: "mcp",
      version: "1.0",
    });

    if (!response.ok) {
      throw new Error(
        `Session handshake failed: ${response.error ?? "Unknown error"}`
      );
    }

    this.sessionId = response.data?.session_id as string;
    if (!this.sessionId) {
      throw new Error(
        "Session handshake succeeded but no session_id was returned."
      );
    }

    const creature = (response.data?.creature ?? {}) as CreatureSnapshot;

    return { sessionId: this.sessionId, creature };
  }

  /**
   * End the current session without closing the socket.
   * The daemon triggers the farewell animation.
   */
  async endSession(): Promise<void> {
    if (!this.sessionId) return;

    try {
      await this.send("disconnect", undefined, {
        session_id: this.sessionId,
      });
    } catch {
      // Best-effort
    }

    this.sessionId = null;
  }

  /**
   * Ping the daemon to check health and drain pending events.
   * Returns the pending events array.
   */
  async ping(): Promise<PendingEvent[]> {
    const response = await this.send("ping");
    return response.pending_events ?? [];
  }

  /**
   * Check if the socket connection to the daemon is active.
   */
  isConnected(): boolean {
    return this.connected;
  }

  /**
   * Get the current session ID, or null if no session is active.
   */
  getSessionId(): string | null {
    return this.sessionId;
  }

  // ─── Private ─────────────────────────────────────────────────────

  /**
   * Handle incoming data from the socket.
   * Buffers partial lines and processes complete NDJSON lines.
   */
  private handleData(chunk: string): void {
    this.buffer += chunk;

    // Safety: prevent buffer from growing unbounded
    if (this.buffer.length > MAX_MESSAGE_SIZE * 2) {
      console.error(
        "[pushling-mcp] Buffer overflow — discarding. " +
          "Daemon may be sending malformed data."
      );
      this.buffer = "";
      return;
    }

    let newlineIndex: number;
    while ((newlineIndex = this.buffer.indexOf("\n")) !== -1) {
      const line = this.buffer.slice(0, newlineIndex).trim();
      this.buffer = this.buffer.slice(newlineIndex + 1);

      if (!line) continue;

      try {
        const response = JSON.parse(line) as IPCResponse;
        this.handleResponse(response);
      } catch {
        console.error(
          "[pushling-mcp] Malformed JSON from daemon:",
          line.slice(0, 200)
        );
      }
    }
  }

  /**
   * Match a response to a pending request and resolve its promise.
   * Also dispatches pending events to the event callback.
   */
  private handleResponse(response: IPCResponse): void {
    // Dispatch pending events
    if (
      response.pending_events &&
      response.pending_events.length > 0 &&
      this.eventCallback
    ) {
      this.eventCallback(response.pending_events);
    }

    // Match to pending request
    const pending = this.pendingRequests.get(response.id);
    if (pending) {
      clearTimeout(pending.timer);
      this.pendingRequests.delete(response.id);
      pending.resolve(response);
    }
    // If no matching pending request, this is a late response (after timeout)
    // or an unsolicited message — silently ignore.
  }

  /**
   * Handle socket disconnection. Rejects pending requests and attempts reconnect.
   */
  private handleDisconnect(error: Error): void {
    const hadSession = this.sessionId !== null;
    this.connected = false;
    this.connecting = false;

    // Reject all pending requests
    for (const [id, pending] of this.pendingRequests) {
      clearTimeout(pending.timer);
      pending.reject(
        new Error(`Daemon connection lost: ${error.message}`)
      );
    }
    this.pendingRequests.clear();

    if (this.socket) {
      this.socket.removeAllListeners();
      this.socket.destroy();
      this.socket = null;
    }

    // Attempt reconnect with exponential backoff
    if (this.reconnectAttempts < MAX_RECONNECT_ATTEMPTS) {
      const delay =
        RECONNECT_BACKOFF_MS[this.reconnectAttempts] ?? 4000;
      this.reconnectAttempts++;

      console.error(
        `[pushling-mcp] Connection lost. Reconnecting in ${delay}ms ` +
          `(attempt ${this.reconnectAttempts}/${MAX_RECONNECT_ATTEMPTS})...`
      );

      this.reconnectTimer = setTimeout(async () => {
        this.reconnectTimer = null;
        try {
          await this.connect();
          // Re-establish session if we had one
          if (hadSession) {
            await this.startSession();
          }
        } catch {
          // Reconnect failed — will retry if attempts remain
          console.error(
            `[pushling-mcp] Reconnect attempt ${this.reconnectAttempts} failed.`
          );
        }
      }, delay);
    } else {
      console.error(
        "[pushling-mcp] Max reconnect attempts reached. " +
          "Daemon connection lost permanently for this session."
      );
    }
  }

  /**
   * Clean up all resources — close socket, clear timers, reject pending.
   */
  private cleanup(): void {
    this.connected = false;
    this.connecting = false;
    this.sessionId = null;

    if (this.reconnectTimer) {
      clearTimeout(this.reconnectTimer);
      this.reconnectTimer = null;
    }

    for (const [, pending] of this.pendingRequests) {
      clearTimeout(pending.timer);
      pending.reject(new Error("Client disconnected"));
    }
    this.pendingRequests.clear();

    if (this.socket) {
      this.socket.removeAllListeners();
      this.socket.destroy();
      this.socket = null;
    }

    this.buffer = "";
  }
}
