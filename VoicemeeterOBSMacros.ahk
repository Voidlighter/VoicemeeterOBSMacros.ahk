#Requires AutoHotkey >=2.0-

; Include the VoicemeeterRemote library
#include lib/OBSWebSocket.ahk
#include lib/VMR.ahk

; Wait until Voicemeeter is running before continuing
;DetectHiddenWindows, On
;WinWait, % VoicemeeterRemote.WindowClass
;DetectHiddenWindows, Off

; Voicemeeter waits a few seconds before starting the audio engine, so we wait
; Sleep, 4000

vm := VMR().Login()

class MyOBSController extends ObsWebSocket {

	state := 0

	AfterIdentified() {
		this.GetCurrentProgramScene()
	}

	GetSceneItemListResponse(data) {
		sceneItemIdsByName := Map()
		For Key, sceneItemData in data.d.responseData.sceneItems
		{
			sceneItemIdsByName[sceneItemData.sourceName] := sceneItemData.sceneItemId
		}

		; this state check is not needed for a simple script such as this one,
		; but might come handy if the events getting more complex
		if (this.state && this.state.name = "toggleSceneItem") {
			this.SetSceneItemEnabled(this.state.sceneName, sceneItemIdsByName[this.state.sceneItem], this.Boolean(this.state.isVisible))
		}
	}

	toggleSceneItem(sceneName, sceneItem, isVisible := -1) {
		this.state := { name: "toggleSceneItem", sceneName: sceneName, sceneItem: sceneItem, isVisible: isVisible }
		this.GetSceneItemList(sceneName)
	}

	changeScene(sceneName) {
		this.SetCurrentProgramScene(sceneName)
	}

}

obsc := MyOBSController("ws://127.0.0.1:4455/", "****************")

sendMuted(isChatMic, isMuted) {
    if isChatMic {
        obsc.toggleSceneItem("Gaming 16:9", "TalkingToChat", isMuted)
    } else {
        obsc.toggleSceneItem("Gaming 16:9", "Muted", isMuted)
    }
}

; SC073 is int 1 (tap)
; SC070 is int 2 (hold)
; SC07D is int 3 (double tap)
; SC079 is int 4 (tap and hold)

; every vm.Strip[X] is actually Strip[X-1] in Voicemeeter

micMuted := vm.Strip[1].Mute
micMutedGame := vm.Bus[6].Mute
micMutedChat := vm.Bus[6].Mute
micMutedDiscord := vm.Bus[6].Mute


SC073::{
	global micMutedGame, micMutedDiscord
    vm.Bus[6].Mute := (micMutedGame := !micMutedGame)
    vm.Bus[8].Mute := (micMutedDiscord := !micMutedDiscord)
    sendMuted(true, micMutedGame)
}

SC070::{
	global micMutedGame, micMutedDiscord
    vm.Bus[6].Mute := !micMutedGame
    vm.Bus[8].Mute := !micMutedDiscord
    sendMuted(true, !micMutedGame)
}

SC070 Up::{
	global micMutedGame, micMutedDiscord
    vm.Bus[6].Mute := micMutedGame
    vm.Bus[8].Mute := micMutedDiscord
    sendMuted(true, micMutedGame)
}

SC07D::{
	global micMuted
    vm.Strip[1].Mute := (micMuted := !micMuted)
    sendMuted(false, micMuted)
}

SC079::{
	global micMuted
    vm.Strip[1].Mute :=! micMuted
    sendMuted(false, !micMuted)
}

SC079 Up::{
	global micMuted
    vm.Strip[1].Mute := micMuted
    sendMuted(false, micMuted)
}
