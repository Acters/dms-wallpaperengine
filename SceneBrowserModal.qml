import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.Modals.Common

DankModal {
    id: root

    property string steamWorkshopPath: ""
    property var sceneList: []
    property string selectedSceneId: ""
    property string searchText: ""

    signal sceneSelected(string sceneId)

    width: Math.min(screenWidth - 100, 1200)
    height: Math.min(screenHeight - 100, 800)
    positioning: "center"
    allowStacking: true

    onDialogClosed: {
        selectedSceneId = ""
        searchText = ""
    }

    content: Item {
        anchors.fill: parent

        Rectangle {
            id: header
            width: parent.width
            height: 60
            color: Theme.surfaceContainer

            Row {
                anchors.left: parent.left
                anchors.leftMargin: Theme.spacingL
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingM

                DankIcon {
                    name: "wallpaper"
                    size: Theme.iconSize
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: "Select Workshop Scene"
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.Bold
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            DankButton {
                anchors.right: parent.right
                anchors.rightMargin: Theme.spacingL
                anchors.verticalCenter: parent.verticalCenter
                text: "Close"
                onClicked: root.close()
            }
        }

        Rectangle {
            id: contentContainer
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: header.bottom
            anchors.bottom: parent.bottom
            width: parent.width
            color: "transparent"

            Column {
                anchors.fill: parent
                anchors.margins: Theme.spacingL
                spacing: Theme.spacingM

                Row {
                    width: parent.width
                    spacing: Theme.spacingM

                    DankTextField {
                        id: searchField
                        width: parent.width - refreshButton.width - Theme.spacingM
                        placeholderText: "Search scenes..."
                        text: root.searchText
                        onTextChanged: {
                            root.searchText = text
                            filterScenes()
                        }
                    }

                    DankButton {
                        id: refreshButton
                        text: "Refresh"
                        onClicked: scanScenes()
                    }
                }

                StyledText {
                    id: sceneCountText
                    text: filteredScenes.count + " scenes found"
                    font.pixelSize: Theme.fontSizeSmall
                    opacity: 0.7
                }

                Rectangle {
                    width: parent.width
                    height: Math.max(200, parent.height - searchField.height - sceneCountText.height - Theme.spacingM * 2)
                    color: Theme.surface
                    radius: Theme.cornerRadius
                    border.width: 1
                    border.color: Theme.outlineStrong

                    GridView {
                        id: sceneGrid
                        anchors.fill: parent
                        anchors.margins: Theme.spacingM
                        cellWidth: 280
                        cellHeight: 220
                        clip: true
                        model: filteredScenes

                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded
                        }

                        delegate: Rectangle {
                            required property var modelData
                            required property int index

                            width: 260
                            height: 200
                            color: mouseArea.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainer
                            radius: Theme.cornerRadius
                            border.width: selectedSceneId === sceneData.sceneId ? 2 : 1
                            border.color: selectedSceneId === sceneData.sceneId ? Theme.primary : Theme.outlineStrong

                            property var sceneData: modelData || {}

                            Column {
                                anchors.fill: parent
                                anchors.margins: Theme.spacingS
                                spacing: Theme.spacingS

                                Rectangle {
                                    width: parent.width
                                    height: 140
                                    radius: Theme.cornerRadius
                                    color: Theme.surface
                                    clip: true

                                    Image {
                                        id: previewImg
                                        anchors.fill: parent
                                        property var extensions: [".jpg", ".jpeg", ".png", ".webp", ".gif", ".bmp"]
                                        property int extIndex: 0
                                        source: {
                                            if (parent.parent.parent.sceneData.sceneId) {
                                                return "file://" + steamWorkshopPath + "/" + parent.parent.parent.sceneData.sceneId + "/preview" + extensions[extIndex]
                                            }
                                            return ""
                                        }
                                        onStatusChanged: {
                                            if (status === Image.Error && extIndex < extensions.length - 1) {
                                                extIndex++
                                            }
                                        }
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true

                                        StyledText {
                                            anchors.centerIn: parent
                                            text: "No Preview"
                                            opacity: 0.5
                                            visible: previewImg.status !== Image.Ready
                                        }
                                    }
                                }

                                StyledText {
                                    width: parent.width
                                    text: parent.parent.sceneData.name || parent.parent.sceneData.sceneId || ""
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.Medium
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    width: parent.width
                                    text: "ID: " + (parent.parent.sceneData.sceneId || "")
                                    font.pixelSize: Theme.fontSizeSmall
                                    opacity: 0.7
                                    elide: Text.ElideRight
                                }
                            }

                            MouseArea {
                                id: mouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    if (parent.sceneData.sceneId) {
                                        selectedSceneId = parent.sceneData.sceneId
                                        sceneSelected(selectedSceneId)
                                        root.close()
                                    }
                                }
                            }
                        }
                    }

                    StyledText {
                        anchors.centerIn: parent
                        text: root.searchText ? "No scenes match your search" : "No scenes found. Make sure Steam Workshop path is correct."
                        opacity: 0.7
                        visible: filteredScenes.count === 0
                        wrapMode: Text.Wrap
                        width: parent.width - 40
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }
    }

    ListModel {
        id: allScenes
    }

    ListModel {
        id: filteredScenes
    }

    Component.onCompleted: {
        scanScenes()
    }

    function scanScenes() {
        if (!steamWorkshopPath) {
            console.warn("No Steam Workshop path set")
            return
        }

        allScenes.clear()
        filteredScenes.clear()

        sceneScanProcess.command = ["ls", "-1", steamWorkshopPath]
        sceneScanProcess.running = true
    }

    Process {
        id: sceneScanProcess
        property string sceneOutput: ""

        stdout: SplitParser {
            onRead: (data) => {
                sceneScanProcess.sceneOutput += data+"\n"
            }
        }

        onExited: (code) => {
            if (code === 0 && sceneOutput) {
                const lines = sceneOutput.trim().split('\n')
                for (const line of lines) {
                    const sceneId = line.trim()
                    if (sceneId && /^\d+$/.test(sceneId)) {
                        const sceneName = readProjectJson(sceneId)
                        allScenes.append({
                            sceneId: sceneId,
                            name: sceneName || sceneId
                        })
                    }
                }
                filterScenes()
            }
            sceneOutput = ""
        }
    }

    function readProjectJson(sceneId) {
        return sceneId
    }

    function filterScenes() {
        filteredScenes.clear()
        const searchTerm = searchText.toLowerCase()

        for (let i = 0; i < allScenes.count; i++) {
            const scene = allScenes.get(i)
            if (!searchTerm ||
                scene.sceneId.includes(searchTerm) ||
                (scene.name && scene.name.toLowerCase().includes(searchTerm))) {
                filteredScenes.append(scene)
            }
        }
    }
}
