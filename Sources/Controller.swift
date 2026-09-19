import Cocoa

/// Observes trackpad touches (listen-only). Note: don't tap the Dock's private swipe events (type 30)
/// instead; any tap on them, even listen-only, stops an auto-hidden Dock from revealing on hover.
private func touchTapCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    if let refcon { Unmanaged<Controller>.fromOpaque(refcon).takeUnretainedValue().handleTouches(type: type, event: event) }
    return Unmanaged.passUnretained(event)
}

/// Mission Control grabs mouse clicks itself, so the overlay panels never see them.
/// A session event tap sees clicks first: clicks on a visible ✕ are swallowed and handled here.
private func eventTapCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passUnretained(event) }
    let controller = Unmanaged<Controller>.fromOpaque(refcon).takeUnretainedValue()
    return controller.handle(type: type, event: event) ? nil : Unmanaged.passUnretained(event)
}

final class Controller {
    private struct Thumb {
        let element: AXUIElement
        let frame: CGRect
        let panel: CloseButtonPanel
    }

    private var thumbs: [ElementKey: Thumb] = [:]
    private var timer: Timer?
    /// Filters clicks; only enabled while Mission Control is open.
    private var tap: CFMachPort?
    private var touchTap: CFMachPort?
    private var swallowingMouseUp = false
    /// Consecutive ticks in which no thumbnail moved. Mission Control animates thumbnails on the way
    /// in and out (and follows your fingers during a swipe), so ✕ buttons only show once everything is still.
    private var stillTicks = 0
    /// A 3-finger swipe is under way. It can pause mid-way with the thumbnails standing still, and
    /// macOS keeps following it if some fingers lift, so it only counts as over once every finger is up.
    private var swiping = false
    private var fingersDown = 0
    private var isSettled: Bool { stillTicks >= 2 && !swiping }
    /// Every window on screen, gathered in the background when Mission Control opens so clicks are instant.
    private var windowIndex: [WindowRef]?
    private var indexGeneration = 0

    func start() { schedule(after: 0.1) }

    /// Polls fast while Mission Control is open so buttons vanish as soon as it starts closing.
    private func schedule(after interval: TimeInterval) {
        let t = Timer(timeInterval: interval, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.tick()
            self.schedule(after: self.thumbs.isEmpty ? 0.1 : 0.03)
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func installTapsIfNeeded() {
        if tap == nil {
            let mask = [CGEventType.leftMouseDown, .leftMouseUp, .mouseMoved, .leftMouseDragged, .keyDown, .scrollWheel,
                        .flagsChanged]
                .reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
            tap = makeTap(mask: mask, options: .defaultTap, callback: eventTapCallback)
            if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        }
        if touchTap == nil {
            touchTap = makeTap(mask: 1 << CGEventMask(NSEvent.EventType.gesture.rawValue), options: .listenOnly,
                               callback: touchTapCallback)
        }
    }

    private func makeTap(mask: CGEventMask, options: CGEventTapOptions, callback: CGEventTapCallBack) -> CFMachPort? {
        guard let port = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: options,
                                           eventsOfInterest: mask, callback: callback,
                                           userInfo: Unmanaged.passUnretained(self).toOpaque()) else { return nil }
        CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, port, 0), .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        return port
    }

    private func setClickTapEnabled(_ enabled: Bool) {
        guard let tap, CGEvent.tapIsEnabled(tap: tap) != enabled else { return }
        CGEvent.tapEnable(tap: tap, enable: enabled)
    }

    private func tick() {
        guard AXIsProcessTrusted() else { return clear() }
        installTapsIfNeeded()
        guard let mc = MissionControl.root() else { return clear() }
        setClickTapEnabled(true)

        if thumbs.isEmpty && windowIndex == nil { refreshWindowIndex() }
        var next: [ElementKey: Thumb] = [:]
        for element in MissionControl.thumbnails(in: mc) {
            guard let frame = element.frame else { continue }
            let key = ElementKey(element: element)
            let panel = thumbs[key]?.panel ?? CloseButtonPanel()
            panel.place(on: frame)
            next[key] = Thumb(element: element, frame: frame, panel: panel)
        }
        for (key, old) in thumbs where next[key] == nil { old.panel.orderOut(nil) }
        let moved = next.count != thumbs.count || next.contains { $0.value.frame != thumbs[$0.key]?.frame }
        stillTicks = moved ? 0 : stillTicks + 1
        thumbs = next
        updateHover(at: CGEvent(source: nil)?.location ?? .zero)
    }

    /// Only the thumbnail under the pointer shows its ✕, and only while Mission Control is at rest.
    private func updateHover(at point: CGPoint) {
        for thumb in thumbs.values {
            let active = isSettled && thumb.frame.union(thumb.panel.axFrame).contains(point)
            thumb.panel.view.hovering = active && thumb.panel.axFrame.contains(point)
            if active, !thumb.panel.isVisible {
                thumb.panel.view.quitMode = CGEventSource.flagsState(.combinedSessionState).contains(.maskAlternate)
                thumb.panel.orderFrontRegardless()
            }
            if !active, thumb.panel.isVisible { thumb.panel.orderOut(nil) }
        }
    }

    /// Returns true when the event should be swallowed.
    fileprivate func handle(type: CGEventType, event: CGEvent) -> Bool {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap, !thumbs.isEmpty { CGEvent.tapEnable(tap: tap, enable: true) }
            return false
        case .mouseMoved, .leftMouseDragged:
            if !thumbs.isEmpty { updateHover(at: event.location) }
            return false
        case .leftMouseDown:
            guard let hit = thumbs.values.first(where: { $0.panel.isVisible && $0.panel.axFrame.contains(event.location) })
            else { hideUntilSettled(); return false } // most clicks in Mission Control dismiss it
            swallowingMouseUp = true
            let quitApp = event.flags.contains(.maskAlternate)
            DispatchQueue.main.async { [weak self] in self?.close(hit.element, quitApp: quitApp) }
            return true
        case .keyDown, .scrollWheel: // Esc, space switching, or the start of a swipe
            if !thumbs.isEmpty { hideUntilSettled() }
            return false
        case .flagsChanged:
            let quitMode = event.flags.contains(.maskAlternate)
            thumbs.values.forEach { $0.panel.view.quitMode = quitMode }
            return false
        case .leftMouseUp:
            defer { swallowingMouseUp = false }
            return swallowingMouseUp
        default:
            return false
        }
    }

    fileprivate func handleTouches(type: CGEventType, event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput, let touchTap {
            CGEvent.tapEnable(tap: touchTap, enable: true)
            return
        }
        guard let ns = NSEvent(cgEvent: event), ns.type == .gesture else { return }
        // Some gesture events carry no touch data at all; they'd otherwise read as "all fingers lifted".
        guard !ns.touches(matching: .any, in: nil).isEmpty else { return }
        let count = ns.touches(matching: .touching, in: nil).count
        guard count != fingersDown else { return }
        fingersDown = count
        if count >= 3 {
            swiping = true
            hideUntilSettled()
        } else if count == 0 && swiping {
            swiping = false
            stillTicks = 0 // Mission Control keeps animating after the fingers lift
        }
    }

    private func hideUntilSettled() {
        stillTicks = 0
        thumbs.values.forEach { $0.panel.orderOut(nil) }
    }

    private func refreshWindowIndex() {
        windowIndex = []
        indexGeneration += 1
        let generation = indexGeneration
        DispatchQueue.global(qos: .userInitiated).async {
            let index = WindowIndex.all()
            DispatchQueue.main.async { [weak self] in
                // Drop results that arrive after Mission Control already closed.
                if let self, self.indexGeneration == generation, self.windowIndex != nil { self.windowIndex = index }
            }
        }
    }

    private func close(_ thumb: AXUIElement, quitApp: Bool) {
        let cached = windowIndex ?? []
        guard let target = WindowIndex.match(thumb, in: cached) ?? WindowIndex.match(thumb, in: WindowIndex.all()) else {
            NSSound.beep()
            return
        }
        if quitApp {
            target.app.terminate()
        } else if let button = target.window.value(kAXCloseButtonAttribute), CFGetTypeID(button) == AXUIElementGetTypeID() {
            if !(button as! AXUIElement).press() { NSSound.beep() }
        } else {
            NSSound.beep()
        }
        // Mission Control updates its thumbnails on its own; the next tick picks up the change.
    }

    private func clear() {
        setClickTapEnabled(false)
        windowIndex = nil
        indexGeneration += 1
        stillTicks = 0
        thumbs.values.forEach { $0.panel.orderOut(nil) }
        thumbs.removeAll()
    }
}
