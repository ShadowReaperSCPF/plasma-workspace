/***************************************************************************
 *   Copyright 2013 Sebastian Kügler <sebas@kde.org>                       *
 *   Copyright 2014, 2016 Kai Uwe Broulik <kde@privat.broulik.de>          *
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU Library General Public License as       *
 *   published by the Free Software Foundation; either version 2 of the    *
 *   License, or (at your option) any later version.                       *
 *                                                                         *
 *   This program is distributed in the hope that it will be useful,       *
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of        *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *
 *   GNU Library General Public License for more details.                  *
 *                                                                         *
 *   You should have received a copy of the GNU Library General Public     *
 *   License along with this program; if not, write to the                 *
 *   Free Software Foundation, Inc.,                                       *
 *   51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA .        *
 ***************************************************************************/

import QtQuick 2.0
import QtQuick.Layouts 1.1
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 2.0 as PlasmaComponents
import org.kde.plasma.extras 2.0 as PlasmaExtras

Item {
    id: expandedRepresentation

    Layout.minimumWidth: Layout.minimumHeight * 1.333
    Layout.minimumHeight: theme.mSize(theme.defaultFont).height * 8
    Layout.preferredWidth: Layout.minimumWidth * 1.5
    Layout.preferredHeight: Layout.minimumHeight * 1.5

    readonly property int controlSize: Math.min(height, width) / 4

    property int position: mpris2Source.data[mpris2Source.current].Position
    property bool disablePositionUpdate: false
    property bool keyPressed: false

    property bool isExpanded: plasmoid.expanded

    function retrievePosition() {
        var service = mpris2Source.serviceForSource(mpris2Source.current);
        var operation = service.operationDescription("GetPosition");
        service.startOperationCall(operation);
    }

    onIsExpandedChanged: {
        if (isExpanded) {
            retrievePosition();
        }
    }

    onPositionChanged: {
        // we don't want to interrupt the user dragging the slider
        if (!seekSlider.pressed && !keyPressed && !queuedPositionUpdate.running) {
            // we also don't want passive position updates
            disablePositionUpdate = true
            seekSlider.value = position
            disablePositionUpdate = false
        }
    }

    Keys.onPressed: keyPressed = true

    Keys.onReleased: {
        keyPressed = false

        if (!event.modifiers) {
            event.accepted = true

            if (event.key === Qt.Key_Space || event.key === Qt.Key_K) {
                // K is YouTube's key for "play/pause" :)
                root.playPause()
            } else if (event.key === Qt.Key_P) {
                root.previous()
            } else if (event.key === Qt.Key_N) {
                root.next()
            } else if (event.key === Qt.Key_S) {
                root.stop()
            } else if (event.key === Qt.Key_Left || event.key === Qt.Key_J) { // TODO ltr languages
                // seek back 5s
                seekSlider.value = Math.max(0, seekSlider.value - 5000000) // microseconds
            } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
                // seek forward 5s
                seekSlider.value = Math.min(seekSlider.maximumValue, seekSlider.value + 5000000)
            } else if (event.key === Qt.Key_Home) {
                seekSlider.value = 0
            } else if (event.key === Qt.Key_End) {
                seekSlider.value = seekSlider.maximumValue
            } else if (event.key >= Qt.Key_0 && event.key <= Qt.Key_9) {
                // jump to percentage, ie. 0 = beginnign, 1 = 10% of total length etc
                seekSlider.value = seekSlider.maximumValue * (event.key - Qt.Key_0) / 10
            } else {
                event.accepted = false
            }
        }
    }

    ColumnLayout {
        id: titleColumn
        width: parent.width
        spacing: units.smallSpacing

        PlasmaComponents.ComboBox {
            id: playerCombo
            Layout.fillWidth: true
            visible: model.length > 2 // more than one player, @multiplex is always there
            model: {
                var model = [{
                    text: i18n("Choose player automatically"),
                    source: mpris2Source.multiplexSource
                }]

                var sources = mpris2Source.sources
                for (var i = 0, length = sources.length; i < length; ++i) {
                    var source = sources[i]
                    if (source === mpris2Source.multiplexSource) {
                        continue
                    }

                    // we could show the pretty player name ("Identity") here but then we
                    // would have to connect all sources just for this
                    model.push({text: source, source: source})
                }

                return model
            }

            onModelChanged: {
                // if model changes, ComboBox resets, so we try to find the current player again...
                for (var i = 0, length = model.length; i < length; ++i) {
                    if (model[i].source === mpris2Source.current) {
                        currentIndex = i
                        break
                    }
                }
            }

            onActivated: {
                disablePositionUpdate = true
                // ComboBox has currentIndex and currentText, why doesn't it have currentItem/currentModelValue?
                mpris2Source.current = model[index].source
                disablePositionUpdate = false
            }
        }

        RowLayout {
            id: titleRow
            Layout.fillWidth: true
            Layout.minimumHeight: albumArt.Layout.preferredHeight
            spacing: units.largeSpacing

            Image {
                id: albumArt
                source: root.albumArt
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
                Layout.preferredHeight: expandedRepresentation.height / 2 - (playerCombo.visible ? playerCombo.height : 0)
                Layout.preferredWidth: Layout.preferredHeight
                visible: !!root.track && status === Image.Ready
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: units.smallSpacing / 2

                PlasmaExtras.Heading {
                    id: song
                    Layout.fillWidth: true
                    level: 3
                    opacity: 0.6

                    maximumLineCount: 3
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    elide: Text.ElideRight
                    text: root.track ? root.track : i18n("No media playing")
                }

                PlasmaExtras.Heading {
                    id: artist
                    Layout.fillWidth: true
                    level: 4
                    opacity: 0.4
                    maximumLineCount: 2
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    visible: text !== ""

                    elide: Text.ElideRight
                    text: root.artist || ""
                }
            }
        }

        PlasmaComponents.Slider {
            id: seekSlider
            Layout.fillWidth: true
            z: 999
            maximumValue: currentMetadata ? currentMetadata["mpris:length"] || 0 : 0
            value: 0
            // if there's no "mpris:length" in teh metadata, we cannot seek, so hide it in that case
            enabled: !root.noPlayer && root.track && currentMetadata && currentMetadata["mpris:length"] && mpris2Source.data[mpris2Source.current].CanSeek
            opacity: enabled ? 1 : 0
            Behavior on opacity {
                NumberAnimation { duration: units.longDuration }
            }

            onValueChanged: {
                if (!disablePositionUpdate) {
                    // delay setting the position to avoid race conditions
                    queuedPositionUpdate.restart()
                }
            }

            onMaximumValueChanged: retrievePosition()

            Timer {
                id: seekTimer
                interval: 1000
                repeat: true
                running: root.state == "playing" && plasmoid.expanded && !keyPressed
                onTriggered: {
                    // some players don't continuously update the seek slider position via mpris
                    // add one second; value in microseconds
                    if (!seekSlider.pressed) {
                        disablePositionUpdate = true
                        if (seekSlider.value == seekSlider.maximumValue) {
                            retrievePosition();
                        } else {
                            seekSlider.value += 1000000
                        }
                        disablePositionUpdate = false
                    }
                }
            }
        }
    }

    Timer {
        id: queuedPositionUpdate
        interval: 100
        onTriggered: {
            var service = mpris2Source.serviceForSource(mpris2Source.current)
            var operation = service.operationDescription("SetPosition")
            operation.microseconds = seekSlider.value
            service.startOperationCall(operation)
        }
    }

    PlasmaComponents.Button {
        anchors {
            right: titleColumn.right
            bottom: titleColumn.bottom
            bottomMargin: seekSlider.height // Cannot anchor around in a column/row, and being lazy
        }
        text: i18nc("Bring the window of player %1 to the front", "Open %1", mpris2Source.data[mpris2Source.current].Identity)
        visible: !root.noPlayer && mpris2Source.data[mpris2Source.current].CanRaise
        onClicked: root.action_openplayer()
    }

    Item {
        anchors.bottom: parent.bottom
        width: parent.width
        height: playerControls.height

        Row {
            id: playerControls
            property bool enabled: !root.noPlayer && mpris2Source.data[mpris2Source.current].CanControl
            property int controlsSize: theme.mSize(theme.defaultFont).height * 3

            anchors.horizontalCenter: parent.horizontalCenter
            spacing: units.largeSpacing

            PlasmaComponents.ToolButton {
                anchors.verticalCenter: parent.verticalCenter
                width: expandedRepresentation.controlSize
                height: width
                enabled: playerControls.enabled && mpris2Source.data[mpris2Source.current].CanGoPrevious
                iconSource: "media-skip-backward"
                onClicked: {
                    seekSlider.value = 0    // Let the media start from beginning. Bug 362473
                    root.previous()
                }
            }

            PlasmaComponents.ToolButton {
                width: expandedRepresentation.controlSize * 1.5
                height: width
                enabled: playerControls.enabled
                iconSource: root.state == "playing" ? "media-playback-pause" : "media-playback-start"
                onClicked: root.playPause()
            }

            PlasmaComponents.ToolButton {
                anchors.verticalCenter: parent.verticalCenter
                width: expandedRepresentation.controlSize
                height: width
                enabled: playerControls.enabled && mpris2Source.data[mpris2Source.current].CanGoNext
                iconSource: "media-skip-forward"
                onClicked: {
                    seekSlider.value = 0    // Let the media start from beginning. Bug 362473
                    root.next()
                }
            }
        }
    }
}
