import QtCore
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.Services
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "linuxWallpaperEngine"

    property var monitors: Quickshell.screens.map(screen => screen.name)
    property string selectedMonitor: monitors.length > 0 ? monitors[0] : ""

    property var steamPaths: {
        var homePath = StandardPaths.writableLocation(StandardPaths.HomeLocation).toString()
        if (homePath.startsWith("file://")) {
            homePath = homePath.substring(7)
        }

        return [
            homePath + "/.local/share/Steam/steamapps/workshop/content/431960",
            homePath + "/.steam/steam/steamapps/workshop/content/431960",
            homePath + "/.var/app/com.valvesoftware.Steam/.local/share/Steam/steamapps/workshop/content/431960",
            homePath + "/snap/steam/common/.local/share/Steam/steamapps/workshop/content/431960"
        ]
    }

    property string steamWorkshopPath: steamPaths[0]
    property int currentPathIndex: 0

    Component.onCompleted: {
        discoverSteamPath()
    }

    function discoverSteamPath() {
        currentPathIndex = 0
        checkNextPath()
    }

    function checkNextPath() {
        if (currentPathIndex >= steamPaths.length) {
            return
        }

        const testPath = steamPaths[currentPathIndex]
        pathCheckProcess.testPath = testPath
        pathCheckProcess.command = ["test", "-d", testPath]
        pathCheckProcess.running = true
    }

    Process {
        id: pathCheckProcess
        property string testPath: ""

        onExited: (code) => {
            if (code === 0) {
                steamWorkshopPath = testPath
            } else {
                currentPathIndex++
                checkNextPath()
            }
        }
    }

    StyledText {
        text: "Linux Wallpaper Engine"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
    }

    StyledText {
        text: "Animated wallpapers using Steam Workshop scenes"
        font.pixelSize: Theme.fontSizeMedium
        opacity: 0.7
        wrapMode: Text.Wrap
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.outlineStrong
    }

    StyledText {
        text: "Monitor"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Medium
    }

    DankDropdown {
        width: parent.width
        options: root.monitors
        currentValue: root.selectedMonitor || "No monitors"
        enabled: root.monitors.length > 1
        compactMode: true

        onValueChanged: (value) => {
            root.selectedMonitor = value
        }
    }

    StyledText {
        text: "Current Scene: " + (getCurrentSceneId() || "None")
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Medium
    }

    StyledRect {
        width: parent.width
        height: 200
        radius: Theme.cornerRadius
        color: Theme.surfaceContainer
        border.width: 1
        border.color: Theme.outlineStrong

        Rectangle {
            id: wallpaperMask

            anchors.fill: parent
            anchors.margins: 1
            radius: Theme.cornerRadius - 1
            color: "black"
            visible: false
            layer.enabled: true
        }

        CachingImage {
            id: previewImage
            anchors.fill: parent
            anchors.margins: 1
            property var weExtensions: [".jpg", ".jpeg", ".png", ".webp", ".gif", ".bmp", ".tga"]
            property int weExtIndex: 0
            source: {
                var sceneId = getCurrentSceneId()
                if (sceneId) {
                    var fullPath = "file://" + steamWorkshopPath + "/" + sceneId + "/preview" + weExtensions[weExtIndex]
                    return fullPath
                }
                return ""
            }
            onStatusChanged: {
                var sceneId = getCurrentSceneId()
                if (sceneId && status === Image.Error) {
                    if (weExtIndex < weExtensions.length - 1) {
                        weExtIndex++
                    } else {
                        visible = false
                    }
                } else if (status === Image.Ready) {
                    visible = true
                }
            }
            fillMode: Image.PreserveAspectCrop
            visible: true
            maxCacheSize: 160
            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: wallpaperMask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1
            }
        }

        StyledText {
            anchors.centerIn: parent
            text: "No scene selected"
            font.pixelSize: Theme.fontSizeMedium
            opacity: 0.7
            visible: !getCurrentSceneId()
        }
    }

    Row {
        width: parent.width
        spacing: Theme.spacingM

        DankButton {
            text: "Browse Scenes"
            width: (parent.width - Theme.spacingM) / 2
            onClicked: {
                browseScenes()
            }
        }

        DankButton {
            text: "Clear"
            width: (parent.width - Theme.spacingM) / 2
            enabled: getCurrentSceneId() !== ""
            onClicked: {
                clearScene()
            }
        }
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.outlineStrong
    }

    StyledText {
        text: "Scene ID"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Medium
    }

    StyledText {
        text: "Enter a Steam Workshop scene ID manually"
        font.pixelSize: Theme.fontSizeSmall
        opacity: 0.7
        wrapMode: Text.Wrap
    }

    Row {
        width: parent.width
        spacing: Theme.spacingM

        DankTextField {
            id: sceneIdField
            width: parent.width - applyButton.width - Theme.spacingM
            placeholderText: "e.g., 1234567890"
            text: getCurrentSceneId() || ""
        }

        DankButton {
            id: applyButton
            text: "Apply"
            enabled: sceneIdField.text.trim() !== ""
            onClicked: {
                setScene(sceneIdField.text.trim())
            }
        }
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.outlineStrong
    }

    StyledText {
        text: "Wallpaper Settings"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Medium
    }

    Item {
        width: parent.width
        height: scalingRow.implicitHeight

        Row {
            id: scalingRow
            width: parent.width
            spacing: Theme.spacingM

            StyledText {
                text: "Scaling:"
                font.pixelSize: Theme.fontSizeSmall
                width: 100
                anchors.verticalCenter: parent.verticalCenter
            }

            DankDropdown {
                width: parent.width - 100 - Theme.spacingM
                options: ["default", "stretch", "fit", "fill"]
                currentValue: getSceneSetting("scaling", "default")
                compactMode: true

                onValueChanged: (value) => {
                    saveSceneSetting("scaling", value)
                }
            }
        }
    }

    Item {
        width: parent.width
        height: fpsRow.implicitHeight

        property int currentFpsValue: getSceneSetting("fps", 30)

        Timer {
            id: fpsDebounceTimer
            interval: 500
            repeat: false
            onTriggered: {
                saveSceneSetting("fps", parent.currentFpsValue)
                PluginService.setGlobalVar("linuxWallpaperEngine", "lastChange", Date.now())
            }
        }

        Row {
            id: fpsRow
            width: parent.width
            spacing: Theme.spacingM

            StyledText {
                text: "FPS:"
                font.pixelSize: Theme.fontSizeSmall
                width: 100
                anchors.verticalCenter: parent.verticalCenter
            }

            DankSlider {
                width: parent.width - 100 - Theme.spacingM - fpsValueText.width - Theme.spacingM
                minimum: 10
                maximum: 144
                showValue: false
                value: parent.parent.currentFpsValue
                anchors.verticalCenter: parent.verticalCenter

                onSliderValueChanged: (newValue) => {
                    parent.parent.currentFpsValue = Math.round(value)
                    fpsDebounceTimer.restart()
                }
            }

            StyledText {
                id: fpsValueText
                text: parent.parent.currentFpsValue
                font.pixelSize: Theme.fontSizeSmall
                width: 40
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    Item {
        width: parent.width
        height: silentRow.implicitHeight

        Row {
            id: silentRow
            width: parent.width
            spacing: Theme.spacingM

            StyledText {
                text: "Silent Mode:"
                font.pixelSize: Theme.fontSizeSmall
                width: 100
                anchors.verticalCenter: parent.verticalCenter
            }

            DankToggle {
                checked: getSceneSetting("silent", true)
                anchors.verticalCenter: parent.verticalCenter

                onToggled: {
                    saveSceneSetting("silent", checked)
                }
            }
        }
    }

    DankButton {
        text: "Configure Scene Properties"
        width: parent.width
        enabled: getCurrentSceneId() !== ""
        onClicked: {
            propertiesModal.open()
        }
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.outlineStrong
    }

    StyledText {
        text: "About"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Medium
    }

    StyledText {
        text: "This plugin uses linux-wallpaperengine to run animated Steam Workshop wallpapers."
        font.pixelSize: Theme.fontSizeSmall
        opacity: 0.7
        wrapMode: Text.Wrap
    }

    StyledText {
        text: "The plugin takes a screenshot of the animated wallpaper and uses it for static contexts (lock screen, color extraction). This will OVERWRITE your current wallpaper settings."
        font.pixelSize: Theme.fontSizeSmall
        opacity: 0.7
        wrapMode: Text.Wrap
    }

    function getCurrentSceneId() {
        var monitorScenes = loadValue("monitorScenes", {})
        return monitorScenes[selectedMonitor] || ""
    }

    function setScene(sceneId) {
        var monitorScenes = loadValue("monitorScenes", {})
        monitorScenes[selectedMonitor] = sceneId
        saveValue("monitorScenes", monitorScenes)
        sceneIdField.text = sceneId
        PluginService.setGlobalVar("linuxWallpaperEngine", "lastChange", Date.now())
        var currentMonitor = selectedMonitor
        selectedMonitor = ""
        selectedMonitor = currentMonitor
    }

    function clearScene() {
        var monitorScenes = loadValue("monitorScenes", {})
        delete monitorScenes[selectedMonitor]
        saveValue("monitorScenes", monitorScenes)
        sceneIdField.text = ""
        PluginService.setGlobalVar("linuxWallpaperEngine", "lastChange", Date.now())
    }

    function browseScenes() {
        sceneBrowser.open()
    }

    function getSceneSettings() {
        var sceneId = getCurrentSceneId()
        if (!sceneId) return {}

        var allSettings = loadValue("sceneSettings", {})
        return allSettings[sceneId] || {}
    }

    function getSceneSetting(key, defaultValue) {
        var settings = getSceneSettings()
        return settings[key] !== undefined ? settings[key] : defaultValue
    }

    function saveSceneSetting(key, value) {
        var sceneId = getCurrentSceneId()
        if (!sceneId) return

        var allSettings = loadValue("sceneSettings", {})
        if (!allSettings[sceneId]) {
            allSettings[sceneId] = {}
        }
        allSettings[sceneId][key] = value
        saveValue("sceneSettings", allSettings)
        PluginService.setGlobalVar("linuxWallpaperEngine", "lastChange", Date.now())
    }

    SceneBrowserModal {
        id: sceneBrowser
        steamWorkshopPath: root.steamWorkshopPath

        onSceneSelected: (sceneId) => {
            setScene(sceneId)
        }
    }

    ScenePropertiesModal {
        id: propertiesModal
        pluginSettings: root

        onOpened: {
            sceneId = getCurrentSceneId()
        }

        onPropertiesSaved: (props) => {
            saveSceneSetting("properties", props)
        }
    }
}
