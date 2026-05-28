import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland._FocusGrab

ShellRoot {
    id: root

    property string home: Quickshell.env("HOME")
    property string wallpaperDir: home + "/Pictures/Wallpapers"
    property string cacheDir: home + "/.cache/wallpaper-selector"
    property string scriptPath: home + "/.config/wallpaper-selector/gen_thumbnails.py"

    readonly property int columns: 3
    readonly property int thumbW: 240
    readonly property int thumbH: 135
    readonly property int gapX: 8
    readonly property int gapY: 8
    readonly property int pad: 16

    property int selectedIndex: 0
    property string originalWallpaper: ""

    function applyWallpaper(path) {
        applyProcess.command = ["hyprctl", "hyprpaper", "wallpaper", "eDP-1, " + path + ", cover"]
        applyProcess.running = true
    }

    function revertAndQuit() {
        if (root.originalWallpaper !== "") {
            revertProcess.command = ["hyprctl", "hyprpaper", "wallpaper", "eDP-1, " + root.originalWallpaper + ", cover"]
            revertProcess.running = true
        } else {
            Qt.quit()
        }
    }

    ListModel { id: wallpaperModel }

    Process {
        id: getActiveProcess
        running: true
        command: ["hyprctl", "hyprpaper", "listactive"]
        stdout: SplitParser {
            onRead: function(line) {
                var idx = line.indexOf(": ")
                if (idx !== -1)
                    root.originalWallpaper = line.substring(idx + 2).trim()
            }
        }
    }

    Process {
        id: scanProcess
        running: true
        command: ["python3", root.scriptPath, root.wallpaperDir, root.cacheDir]
        stdout: SplitParser {
            onRead: function(line) {
                var parts = line.trim().split("\t")
                if (parts.length === 2)
                    wallpaperModel.append({ imagePath: parts[0], thumbPath: parts[1] })
            }
        }
    }

    Process {
        id: applyProcess
        stderr: SplitParser { onRead: function(line) { console.log("ERR:", line) } }
        stdout: SplitParser { onRead: function(line) { console.log("OUT:", line) } }
    }

    Process {
        id: revertProcess
        onRunningChanged: {
            if (!running) Qt.quit()
        }
        stderr: SplitParser { onRead: function(line) { console.log("ERR:", line) } }
    }

    PanelWindow {
        id: panel
        anchors.left: true
        anchors.right: true
        anchors.top: true
        anchors.bottom: true
        color: "transparent"
        focusable: true
        aboveWindows: true
        exclusionMode: ExclusionMode.Ignore

        HyprlandFocusGrab {
            active: true
            windows: [panel]
            onCleared: root.revertAndQuit()
        }

        Rectangle {
            id: container
            anchors.centerIn: parent
            width: root.columns * (root.thumbW + root.gapX) + root.pad * 2
            height: 450
            color: "#50FFFFFF"
            radius: 16
            focus: true

            Keys.onPressed: function(event) {
                var count = wallpaperModel.count
                if (count === 0) return

                switch (event.key) {
                    case Qt.Key_Escape:
                        root.revertAndQuit()
                        break
                    case Qt.Key_Return:
                    case Qt.Key_Enter:
                        Qt.quit()
                        break
                    case Qt.Key_Left:
                        root.selectedIndex = Math.max(0, root.selectedIndex - 1)
                        grid.positionViewAtIndex(root.selectedIndex, GridView.Contain)
                        root.applyWallpaper(wallpaperModel.get(root.selectedIndex).imagePath)
                        break
                    case Qt.Key_Right:
                        root.selectedIndex = Math.min(count - 1, root.selectedIndex + 1)
                        grid.positionViewAtIndex(root.selectedIndex, GridView.Contain)
                        root.applyWallpaper(wallpaperModel.get(root.selectedIndex).imagePath)
                        break
                    case Qt.Key_Up:
                        root.selectedIndex = Math.max(0, root.selectedIndex - root.columns)
                        grid.positionViewAtIndex(root.selectedIndex, GridView.Contain)
                        root.applyWallpaper(wallpaperModel.get(root.selectedIndex).imagePath)
                        break
                    case Qt.Key_Down:
                        root.selectedIndex = Math.min(count - 1, root.selectedIndex + root.columns)
                        grid.positionViewAtIndex(root.selectedIndex, GridView.Contain)
                        root.applyWallpaper(wallpaperModel.get(root.selectedIndex).imagePath)
                        break
                }
                event.accepted = true
            }

            GridView {
                id: grid
                anchors.fill: parent
                anchors.margins: root.pad
                cellWidth: root.thumbW + root.gapX
                cellHeight: root.thumbH + root.gapY
                clip: true
                model: wallpaperModel

                delegate: Item {
                    width: grid.cellWidth
                    height: grid.cellHeight

                    Image {
                        anchors.centerIn: parent
                        width: root.thumbW
                        height: root.thumbH
                        source: "file://" + model.thumbPath
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: {
                            root.selectedIndex = index
                            root.applyWallpaper(model.imagePath)
                        }
                        onClicked: Qt.quit()
                    }
                }

                Rectangle {
                    id: selector
                    width: root.thumbW
                    height: root.thumbH
                    color: "transparent"
                    border.width: 2
                    border.color: "white"
                    radius: 8
                    z: 99

                    x: (root.selectedIndex % root.columns) * grid.cellWidth + (grid.cellWidth - root.thumbW) / 2
                    y: Math.floor(root.selectedIndex / root.columns) * grid.cellHeight + (grid.cellHeight - root.thumbH) / 2 - grid.contentY

                    Behavior on x { SmoothedAnimation { duration: 150 } }
                    Behavior on y { SmoothedAnimation { duration: 200 } }
                }
            }
        }
    }
}
