; AutoHotkey script that enables you to use GPT3 in any input field on your computer

; -- Configuration --
#SingleInstance ; Allow only one instance of this script to be running.

#NoEnv ; Recommended for performance and compatibility with future AutoHotkey releases.

; -- Initialization --
; Dependencies
; WinHttpRequest: https://www.reddit.com/comments/mcjj4s
; cJson.ahk: https://github.com/G33kDude/cJson.ahk
#Include <Json>
http := WinHttpRequest()

I_Icon = GPT3-AHK.ico
IfExist, %I_Icon%
   Menu, Tray, Icon, %I_Icon%

; This is the hotkey used to autocomplete prompts
HOTKEY_AUTOCOMPLETE = #o ; Win+o
; This is the hotkey used to edit prompts
HOTKEY_INSTRUCT = #+o ; Win+shift+o
; Models settings
MODEL_AUTOCOMPLETE_ID := "gpt-3.5-turbo"
MODEL_AUTOCOMPLETE_MAX_TOKENS := 2048
MODEL_AUTOCOMPLETE_TEMP := 0.8
MODEL_INSTRUCT_ID := "gpt-3.5-turbo"

Try
{
   EnvGet, API_KEY, OPENAI_API_KEY
}
Catch
{
   InputBox, API_KEY, Please insert your OpenAI API key, API_KEY, , 270, 145
   IniWrite, %API_KEY%, settings.ini, OpenAI, API_KEY
   IniRead, API_KEY, settings.ini, OpenAI, API_KEY
}

; Add your GPTNOTES folder as an environment variable. This way GPT-3-AHK can save completions and instructions to a file. Alternatively, you can set the  variable GPTNOTES in the settings.ini file.

Try
{
   EnvGet, NOTES, GPTNOTES
}
Catch
{
   InputBox, NOTES, Please insert the full path to your NOTES folder, NOTES, , 270, 145
   IniWrite, %NOTES%, settings.ini, NOTES, NOTES
   IniRead, NOTES, settings.ini, NOTES, NOTES
}

notes_file = %NOTES%\%A_YYYY%-%A_MM%-%A_DD%_GPTresponses.md

Hotkey, %HOTKEY_AUTOCOMPLETE%, AutocompleteFcn
Hotkey, %HOTKEY_INSTRUCT%, InstructFcn
OnExit("ExitFunc")

Return

; -- Main commands --
; Edit the phrase
InstructFcn:
   ; a message box that ask the user if he wants to replace the edited text or keep it. If replace, set method to: Cut, if keep, set method to: AddSpace
   SetTimer, ChangeButtonNamesVar, 50
   MsgBox, 36, Keep or Replace?, Do you want to keep or replace the highlighted text?`n`nKeep: The edited text will be added after the highlighted text.`nReplace: The highlighted text will be replaced by the edited text.
   IfMsgBox, Yes
   {
      put_option := "AddSpace"
      action := "Copy"
   }
   else{
      put_option := ""
      action := "Cut"
   }
   GetText(CutText, action)
   InputBox, UserInput, Text to edit "%CutText%", Enter an instruction, , 270, 145
   if ErrorLevel {
      PutText(CutText)
   }else{
      url := "https://api.openai.com/v1/chat/completions"
      body := {}
      body.model := MODEL_INSTRUCT_ID ; ID of the model to use.
      ; body.input := ; The prompt to edit.
      body.messages := [{"role":"system", "content": "You are a helpful text editor AI. You've got over 20 years of editing and writing all kinds of text. If you write German, use the Du-Form. Here is what I need you to do for me:" UserInput},{"role": "user", "content": CutText}] ; The instruction that tells how to edit the prompt
      body.max_tokens := MODEL_AUTOCOMPLETE_MAX_TOKENS ; The maximum number of  tokens to generate in the completion.
      body.temperature := MODEL_AUTOCOMPLETE_TEMP - 0.3 ; Sampling temperature to use
      headers := {"Content-Type": "application/json", "Authorization": "Bearer " . API_KEY}
      SetSystemCursor()
      response := http.POST(url, JSON.Dump(body), headers, {Object:true, Encoding:"UTF-8"})
      obj := JSON.Load(response.Text)
      PutText(obj.choices[1].message.content , put_option)
      response := obj.choices[1].message.content
      FileAppend, ## %A_Hour%:%A_Min% GPT Response`n`n,%notes_file%, UTF-8-RAW
      FileAppend, **Instruct:**`n%UserInput%`n `n, %notes_file%, UTF-8-RAW
      FileAppend, **Text:**`n%CutText%`n `n, %notes_file%, UTF-8-RAW
      FileAppend, **Response:**`n%response%`n `n, %notes_file%, UTF-8-RAW
      RestoreCursors()
   }
Return

; Auto-complete the phrase
AutocompleteFcn:
   GetText(CopiedText, "Copy")
   url := "https://api.openai.com/v1/chat/completions"
   body := {}
   body.model := MODEL_AUTOCOMPLETE_ID ; ID of the model to use.
   body.messages := [{"role":"system", "content": "You are a friendly, hepful AI. Answer in the language the user prompt is written in. If it's German, write in Du-Form. Complete the following sentence or text:"},{"role": "user", "content": CopiedText}] ; The prompt to generate completions for
   body.max_tokens := MODEL_AUTOCOMPLETE_MAX_TOKENS ; The maximum number of tokens to generate in the completion.
   body.temperature := MODEL_AUTOCOMPLETE_TEMP + 0 ; Sampling temperature to use
   headers := {"Content-Type": "application/json", "Authorization": "Bearer " . API_KEY}
   SetSystemCursor()
   response := http.POST(url, JSON.Dump(body), headers, {Object:true, Encoding:"UTF-8"})
   obj := JSON.Load(response.Text)
   PutText(obj.choices[1].message.content, "AddSpace")
   response := obj.choices[1].message.content
   FileAppend, ## %A_Hour%:%A_Min% GPT Response`n`n,%notes_file%, UTF-8-RAW
   FileAppend, **Text:**`n%CopiedText%`n `n, %notes_file%, UTF-8-RAW
   FileAppend, **Completion:**`n%response%`n `n, %notes_file%, UTF-8-RAW

   RestoreCursors()
Return

; -- Auxiliar functions --
; Change Button names of the message box for the "Keep or Replace?" question
ChangeButtonNamesVar:
   IfWinNotExist, Keep or Replace?
      Return ; Keep waiting
   SetTimer, ChangeButtonNamesVar, Off
   WinActivate,
   ControlSetText, Button1, Keep, Keep or Replace?
   ControlSetText, Button2, Replace, Keep or Replace?
Return

; Copies the selected text to a variable while preserving the clipboard.
GetText(ByRef MyText = "", Option = "Copy")
{
   SavedClip := ClipboardAll
   Clipboard =
   If (Option == "Copy")
   {
      Send ^c
   }
   Else If (Option == "Cut")
   {
      Send ^x
   }
   ClipWait 0.5
   If ERRORLEVEL
   {
      Clipboard := SavedClip
      MyText =
      Return
   }
   MyText := Clipboard
   Clipboard := SavedClip
   Return MyText
}

; Send text from a variable while preserving the clipboard.
PutText(MyText, Option = "")
{
   ; Save clipboard and paste MyText
   SavedClip := ClipboardAll
   Clipboard =
   Sleep 20
   Clipboard := MyText

   If (Option == "AddSpace")
   {
      Send {Right}
      Send {Space}
   }
   Send ^v
   Sleep 100
   Clipboard := SavedClip
   Return
}

; Change system cursor
SetSystemCursor()
{
   Cursor = %A_ScriptDir%\GPT3-AHK.ani
   CursorHandle := DllCall( "LoadCursorFromFile", Str,Cursor )

   Cursors = 32512,32513,32514,32515,32516,32640,32641,32642,32643,32644,32645,32646,32648,32649,32650,32651
   Loop, Parse, Cursors, `,
   {
      DllCall( "SetSystemCursor", Uint,CursorHandle, Int,A_Loopfield )
   }
}

RestoreCursors()
{
   DllCall( "SystemParametersInfo", UInt, 0x57, UInt,0, UInt,0, UInt,0 )
}

ExitFunc(ExitReason, ExitCode)
{
   if ExitReason not in Logoff,Shutdown
   {
      RestoreCursors()
   }
}
