/*
    The Mauvely splash: the mark on the dark wallpaper's ground, with a busy ring below.
    The mark and the ring sit where the Plymouth theme puts its watermark and spinner
    (os-image, /usr/share/plymouth/themes/mauvely), so boot to desktop reads as one screen.
    Breeze's splash protocol: fade in at stage 2, fade the ring out at stage 5.

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.kirigami as Kirigami

Rectangle {
    id: root
    color: "#12142e"

    property int stage

    onStageChanged: {
        if (stage == 2) {
            introAnimation.running = true;
        } else if (stage == 5) {
            introAnimation.target = busyIndicator;
            introAnimation.from = 1;
            introAnimation.to = 0;
            introAnimation.running = true;
        }
    }

    Item {
        id: content
        anchors.fill: parent
        opacity: 0

        // Plymouth's two-step places an image at (screen - image) * alignment.
        Image {
            id: mark
            readonly property real size: Kirigami.Units.gridUnit * 6
            x: (parent.width - width) / 2
            y: (parent.height - height) * 0.45
            asynchronous: true
            source: "images/mark.svg"
            sourceSize.height: size
        }

        Image {
            id: busyIndicator
            x: (parent.width - width) / 2
            y: (parent.height - height) * 0.7
            asynchronous: true
            source: "images/busy.svg"
            sourceSize.width: Kirigami.Units.gridUnit * 2
            sourceSize.height: Kirigami.Units.gridUnit * 2
            RotationAnimator on rotation {
                from: 0
                to: 360
                duration: 1200
                loops: Animation.Infinite
                // Still when the person has turned animations off
                running: Kirigami.Units.longDuration > 1
            }
        }
    }

    OpacityAnimator {
        id: introAnimation
        running: false
        target: content
        from: 0
        to: 1
        duration: Kirigami.Units.veryLongDuration * 2
        easing.type: Easing.InOutQuad
    }
}
