// AppDelegate+Debug.swift — Debug menu building and @objc action forwarding
// Extracted from AppDelegate.swift to stay under 500 lines per file.
// All debug menu items and their @objc action methods live here.

import AppKit
import QuartzCore

// MARK: - Debug Menu Building & Actions

extension AppDelegate {

    // MARK: - Menu Construction

    func buildDebugSubmenu() -> NSMenu {
        let menu = NSMenu(title: "Debug")

        // --- Feed Commits ---
        addHeader(to: menu, title: "Feed Commits")
        addItem(to: menu, "Feed Small Commit (10 lines)",
                #selector(debugFeedSmallCommit))
        addItem(to: menu, "Feed Large Commit (200 lines)",
                #selector(debugFeedLargeCommit))
        addItem(to: menu, "Feed Test Commit",
                #selector(debugFeedTestCommit))
        addItem(to: menu, "Feed 10 Commits",
                #selector(debugFeed10Commits))
        addItem(to: menu, "Feed 50 Commits",
                #selector(debugFeed50Commits))
        menu.addItem(.separator())

        // --- Change Stage ---
        addHeader(to: menu, title: "Change Stage")
        addItem(to: menu, "Set Stage: Spore",  #selector(debugSetSpore))
        addItem(to: menu, "Set Stage: Drop",   #selector(debugSetDrop))
        addItem(to: menu, "Set Stage: Critter", #selector(debugSetCritter))
        addItem(to: menu, "Set Stage: Beast",  #selector(debugSetBeast))
        addItem(to: menu, "Set Stage: Sage",   #selector(debugSetSage))
        addItem(to: menu, "Set Stage: Apex",   #selector(debugSetApex))
        menu.addItem(.separator())

        // --- Evolution ---
        addHeader(to: menu, title: "Evolution")
        addItem(to: menu, "Evolve Now", #selector(debugEvolveNow))
        menu.addItem(.separator())

        // --- Expressions ---
        addHeader(to: menu, title: "Expressions")
        addItem(to: menu, "Express Joy",        #selector(debugExpressJoy))
        addItem(to: menu, "Express Curiosity",   #selector(debugExpressCuriosity))
        addItem(to: menu, "Express Surprise",    #selector(debugExpressSurprise))
        addItem(to: menu, "Express Love",        #selector(debugExpressLove))
        addItem(to: menu, "Express Mischief",    #selector(debugExpressMischief))
        addItem(to: menu, "Express Wonder",      #selector(debugExpressWonder))
        addItem(to: menu, "Express Sleepy",      #selector(debugExpressSleepy))
        addItem(to: menu, "Express Melancholy",  #selector(debugExpressMelancholy))
        menu.addItem(.separator())

        // --- Speech ---
        addHeader(to: menu, title: "Test Speech")
        addItem(to: menu, "Say Hello",        #selector(debugSayHello))
        addItem(to: menu, "Say Long Message",  #selector(debugSayLong))
        addItem(to: menu, "Test First Word",   #selector(debugTestFirstWord))
        menu.addItem(.separator())

        // --- Weather ---
        addHeader(to: menu, title: "Test Weather")
        addItem(to: menu, "Set Clear",  #selector(debugWeatherClear))
        addItem(to: menu, "Set Cloudy", #selector(debugWeatherCloudy))
        addItem(to: menu, "Set Rain",   #selector(debugWeatherRain))
        addItem(to: menu, "Set Storm",  #selector(debugWeatherStorm))
        addItem(to: menu, "Set Snow",   #selector(debugWeatherSnow))
        addItem(to: menu, "Set Fog",    #selector(debugWeatherFog))
        menu.addItem(.separator())

        // --- Surprises ---
        addHeader(to: menu, title: "Surprises")
        addItem(to: menu, "Trigger Random Surprise",
                #selector(debugSurpriseRandom))
        addItem(to: menu, "Trigger Zoomies (#27)",
                #selector(debugSurpriseZoomies))
        addItem(to: menu, "Trigger Tail Chase (#30)",
                #selector(debugSurpriseTailChase))
        addItem(to: menu, "Trigger Tongue Blep (#42)",
                #selector(debugSurpriseBlep))
        addItem(to: menu, "Trigger Loaf (#33)",
                #selector(debugSurpriseLoaf))
        addItem(to: menu, "Trigger Knock Off (#28)",
                #selector(debugSurpriseKnockOff))
        menu.addItem(.separator())

        // --- Touch / Input ---
        addHeader(to: menu, title: "Touch / Input")
        addItem(to: menu, "Simulate Tap on Creature",
                #selector(debugSimulateTap))
        addItem(to: menu, "Simulate Double-Tap",
                #selector(debugSimulateDoubleTap))
        addItem(to: menu, "Simulate Petting Stroke",
                #selector(debugSimulatePetting))
        addItem(to: menu, "Toggle Laser Pointer (auto-move)",
                #selector(debugToggleLaser))
        addItem(to: menu, "Show Touch Milestone Progress",
                #selector(debugShowMilestones))
        menu.addItem(.separator())

        // --- Mini-Games ---
        addHeader(to: menu, title: "Mini-Games")
        addItem(to: menu, "Start Catch Game",
                #selector(debugGameCatch))
        addItem(to: menu, "Start Rhythm Tap Game",
                #selector(debugGameRhythm))
        menu.addItem(.separator())

        // --- World Objects ---
        addHeader(to: menu, title: "World Objects")
        addItem(to: menu, "Place Ball",          #selector(debugPlaceBall))
        addItem(to: menu, "Place Campfire",       #selector(debugPlaceCampfire))
        addItem(to: menu, "Place Cardboard Box",  #selector(debugPlaceBox))
        addItem(to: menu, "Remove All Objects",   #selector(debugRemoveObjects))
        menu.addItem(.separator())

        // --- Companions ---
        addHeader(to: menu, title: "Companions")
        addItem(to: menu, "Add Mouse Companion",  #selector(debugAddMouse))
        addItem(to: menu, "Add Bird Companion",   #selector(debugAddBird))
        addItem(to: menu, "Remove Companion",      #selector(debugRemoveCompanion))
        menu.addItem(.separator())

        // --- Mutations ---
        addHeader(to: menu, title: "Mutations")
        addItem(to: menu, "Check All Badges",     #selector(debugCheckBadges))
        addItem(to: menu, "Grant Nocturne Badge",  #selector(debugGrantNocturne))
        addItem(to: menu, "Grant Marathon Badge",   #selector(debugGrantMarathon))
        menu.addItem(.separator())

        // --- Teach ---
        addHeader(to: menu, title: "Teach")
        addItem(to: menu, "Teach Roll Over (demo trick)",
                #selector(debugTeachRollOver))
        addItem(to: menu, "List Taught Tricks",
                #selector(debugListTricks))
        menu.addItem(.separator())

        // --- Nurture ---
        addHeader(to: menu, title: "Nurture")
        addItem(to: menu, "Add Habit: Stretch After Commit",
                #selector(debugNurtureStretch))
        addItem(to: menu, "Add Preference: Loves Rain",
                #selector(debugNurtureLovesRain))
        addItem(to: menu, "List Active Habits",
                #selector(debugListHabits))
        menu.addItem(.separator())

        // --- Session ---
        addHeader(to: menu, title: "Session")
        addItem(to: menu, "Simulate Claude Connect",
                #selector(debugSessionConnect))
        addItem(to: menu, "Simulate Claude Disconnect",
                #selector(debugSessionDisconnect))
        addItem(to: menu, "Show Diamond Indicator",
                #selector(debugShowDiamond))
        menu.addItem(.separator())

        // --- Interactions ---
        addHeader(to: menu, title: "Interactions")
        addItem(to: menu, "Test Cat Behavior",
                #selector(debugTestCatBehavior))
        menu.addItem(.separator())

        // --- Time ---
        addHeader(to: menu, title: "Time")
        addItem(to: menu, "Skip 1 Hour",     #selector(debugSkip1Hour))
        addItem(to: menu, "Skip to Morning",  #selector(debugSkipToMorning))
        addItem(to: menu, "Skip to Night",    #selector(debugSkipToNight))
        menu.addItem(.separator())

        // --- Camera ---
        addHeader(to: menu, title: "Camera")
        addItem(to: menu, "Zoom In (+0.25)",   #selector(debugZoomIn))
        addItem(to: menu, "Zoom Out (-0.25)",  #selector(debugZoomOut))
        addItem(to: menu, "Reset Zoom (1.0x)", #selector(debugZoomReset))
        addItem(to: menu, "Show Camera State",  #selector(debugShowCameraState))
        menu.addItem(.separator())

        // --- Info ---
        addHeader(to: menu, title: "Info")
        addItem(to: menu, "Show Full Stats (Console)",
                #selector(debugShowFullStats))
        addItem(to: menu, "Show World State",
                #selector(debugShowWorldState))
        addItem(to: menu, "Show Behavior Stack State",
                #selector(debugShowBehaviorStack))
        addItem(to: menu, "Export Creature JSON",
                #selector(debugExportJSON))

        return menu
    }

    // MARK: - Menu Helpers

    private func addHeader(to menu: NSMenu, title: String) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
    }

    private func addItem(to menu: NSMenu, _ title: String,
                         _ action: Selector) {
        let item = NSMenuItem(title: title, action: action,
                              keyEquivalent: "")
        item.target = self
        menu.addItem(item)
    }

    // MARK: - Debug Actions Helper

    func ensureDebugActions() -> DebugActions {
        if let existing = debugActions {
            existing.updateScene(touchBarController?.currentScene)
            existing.updateGameCoordinator(gameCoordinator)
            return existing
        }
        let actions = DebugActions(
            scene: touchBarController?.currentScene,
            gameCoordinator: gameCoordinator
        )
        debugActions = actions
        return actions
    }

    // MARK: - Feed Commits

    @objc func debugFeedSmallCommit() {
        ensureDebugActions().feedSmallCommit()
    }

    @objc func debugFeedLargeCommit() {
        ensureDebugActions().feedLargeCommit()
    }

    @objc func debugFeedTestCommit() {
        ensureDebugActions().feedTestCommit()
    }

    @objc func debugFeed10Commits() {
        ensureDebugActions().feedBatchCommits(count: 10)
    }

    @objc func debugFeed50Commits() {
        ensureDebugActions().feedBatchCommits(count: 50)
    }

    // MARK: - Stage

    @objc func debugSetSpore()   { ensureDebugActions().setStage(.egg) }
    @objc func debugSetDrop()    { ensureDebugActions().setStage(.drop) }
    @objc func debugSetCritter() { ensureDebugActions().setStage(.critter) }
    @objc func debugSetBeast()   { ensureDebugActions().setStage(.beast) }
    @objc func debugSetSage()    { ensureDebugActions().setStage(.sage) }
    @objc func debugSetApex()    { ensureDebugActions().setStage(.apex) }

    // MARK: - Evolution

    @objc func debugEvolveNow() { ensureDebugActions().evolveNow() }

    // MARK: - Expressions

    @objc func debugExpressJoy() {
        ensureDebugActions().express("joy")
    }
    @objc func debugExpressCuriosity() {
        ensureDebugActions().express("curiosity")
    }
    @objc func debugExpressSurprise() {
        ensureDebugActions().express("surprise")
    }
    @objc func debugExpressLove() {
        ensureDebugActions().express("love")
    }
    @objc func debugExpressMischief() {
        ensureDebugActions().express("mischief")
    }
    @objc func debugExpressWonder() {
        ensureDebugActions().express("wonder")
    }
    @objc func debugExpressSleepy() {
        ensureDebugActions().express("sleepy")
    }
    @objc func debugExpressMelancholy() {
        ensureDebugActions().express("melancholy")
    }

    // MARK: - Speech

    @objc func debugSayHello()     { ensureDebugActions().sayHello() }
    @objc func debugSayLong()      { ensureDebugActions().sayLongMessage() }
    @objc func debugTestFirstWord() { ensureDebugActions().testFirstWord() }

    // MARK: - Weather

    @objc func debugWeatherClear() { ensureDebugActions().setWeather(.clear) }
    @objc func debugWeatherCloudy() { ensureDebugActions().setWeather(.cloudy) }
    @objc func debugWeatherRain()  { ensureDebugActions().setWeather(.rain) }
    @objc func debugWeatherStorm() { ensureDebugActions().setWeather(.storm) }
    @objc func debugWeatherSnow()  { ensureDebugActions().setWeather(.snow) }
    @objc func debugWeatherFog()   { ensureDebugActions().setWeather(.fog) }

    // MARK: - Surprises

    @objc func debugSurpriseRandom() {
        ensureDebugActions().triggerSurprise(id: nil)
    }
    @objc func debugSurpriseZoomies() {
        ensureDebugActions().triggerSurprise(id: 27)
    }
    @objc func debugSurpriseTailChase() {
        ensureDebugActions().triggerSurprise(id: 30)
    }
    @objc func debugSurpriseBlep() {
        ensureDebugActions().triggerSurprise(id: 42)
    }
    @objc func debugSurpriseLoaf() {
        ensureDebugActions().triggerSurprise(id: 33)
    }
    @objc func debugSurpriseKnockOff() {
        ensureDebugActions().triggerSurprise(id: 28)
    }

    // MARK: - Touch / Input

    @objc func debugSimulateTap() {
        ensureDebugActions().simulateTap()
    }
    @objc func debugSimulateDoubleTap() {
        ensureDebugActions().simulateDoubleTap()
    }
    @objc func debugSimulatePetting() {
        ensureDebugActions().simulatePetting()
    }
    @objc func debugToggleLaser() {
        ensureDebugActions().toggleLaserPointer()
    }
    @objc func debugShowMilestones() {
        ensureDebugActions().showMilestoneProgress()
    }

    // MARK: - Mini-Games

    @objc func debugGameCatch() {
        ensureDebugActions().startGame(.catchStars)
    }
    @objc func debugGameRhythm() {
        ensureDebugActions().startGame(.rhythmTap)
    }

    // MARK: - World Objects

    @objc func debugPlaceBall() {
        ensureDebugActions().placeObject("ball")
    }
    @objc func debugPlaceCampfire() {
        ensureDebugActions().placeObject("campfire")
    }
    @objc func debugPlaceBox() {
        ensureDebugActions().placeObject("cardboard_box")
    }
    @objc func debugRemoveObjects() {
        ensureDebugActions().removeAllObjects()
    }

    // MARK: - Companions

    @objc func debugAddMouse() {
        ensureDebugActions().addCompanion("mouse")
    }
    @objc func debugAddBird() {
        ensureDebugActions().addCompanion("bird")
    }
    @objc func debugRemoveCompanion() {
        ensureDebugActions().removeCompanion()
    }

    // MARK: - Mutations

    @objc func debugCheckBadges() {
        ensureDebugActions().checkAllBadges()
    }
    @objc func debugGrantNocturne() {
        ensureDebugActions().grantBadge(.nocturne)
    }
    @objc func debugGrantMarathon() {
        ensureDebugActions().grantBadge(.marathon)
    }

    // MARK: - Teach

    @objc func debugTeachRollOver() {
        ensureDebugActions().teachRollOver()
    }
    @objc func debugListTricks() {
        ensureDebugActions().listTaughtTricks()
    }

    // MARK: - Nurture

    @objc func debugNurtureStretch() {
        ensureDebugActions().addHabit("stretch_after_commit")
    }
    @objc func debugNurtureLovesRain() {
        ensureDebugActions().addPreference("loves_rain")
    }
    @objc func debugListHabits() {
        ensureDebugActions().listActiveHabits()
    }

    // MARK: - Session

    @objc func debugSessionConnect() {
        ensureDebugActions().simulateClaudeConnect()
    }
    @objc func debugSessionDisconnect() {
        ensureDebugActions().simulateClaudeDisconnect()
    }
    @objc func debugShowDiamond() {
        ensureDebugActions().showDiamondIndicator()
    }

    // MARK: - Interactions

    @objc func debugTestCatBehavior() {
        ensureDebugActions().testCatBehavior()
    }

    // MARK: - Time

    @objc func debugSkip1Hour() {
        ensureDebugActions().skipTime(hours: 1)
    }
    @objc func debugSkipToMorning() {
        ensureDebugActions().skipToMorning()
    }
    @objc func debugSkipToNight() {
        ensureDebugActions().skipToNight()
    }

    // MARK: - Camera

    @objc func debugZoomIn() {
        ensureDebugActions().zoomIn()
    }
    @objc func debugZoomOut() {
        ensureDebugActions().zoomOut()
    }
    @objc func debugZoomReset() {
        ensureDebugActions().zoomReset()
    }
    @objc func debugShowCameraState() {
        ensureDebugActions().showCameraState()
    }

    // MARK: - Info

    @objc func debugShowFullStats() {
        ensureDebugActions().showFullStats()
    }
    @objc func debugShowWorldState() {
        ensureDebugActions().showWorldState()
    }
    @objc func debugShowBehaviorStack() {
        ensureDebugActions().showBehaviorStackState()
    }
    @objc func debugExportJSON() {
        ensureDebugActions().exportCreatureJSON()
    }
}
