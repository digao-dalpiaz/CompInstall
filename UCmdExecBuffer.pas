unit UCmdExecBuffer;

interface

{The TCmdExecBuffer class executes command line programs in cmd.exe
and allows to retrieve line by line output using OnLine event.}

type
  TCmdExecBufferEvLine = procedure(const Text: string) of object;

  TCmdExecBuffer = class
  public
    OnLine: TCmdExecBufferEvLine; //event to retrieve line by line output

    CommandLine: string;
    WorkDir: string;

    Lines: string; //all output lines
    ExitCode: Cardinal;
    function Exec: Boolean; //function to execute the program
  end;

implementation

uses Winapi.Windows;

function TCmdExecBuffer.Exec: Boolean;
var
  SA: TSecurityAttributes;
  SI: TStartupInfo;
  PI: TProcessInformation;
  StdOutPipeRead, StdOutPipeWrite: THandle;
  WasOK: Boolean;
  Buffer: array[0..255] of AnsiChar;
  BytesRead: Cardinal;
  Handle: Boolean;
  aLine: string;
begin
  Result := False;
  Lines := '';
  //ExitCode := (-1);

  with SA do
  begin
    nLength := SizeOf(SA);
    bInheritHandle := True;
    lpSecurityDescriptor := nil;
  end;
  CreatePipe(StdOutPipeRead, StdOutPipeWrite, @SA, 0);
  try
    with SI do
    begin
      FillChar(SI, SizeOf(SI), 0);
      cb := SizeOf(SI);
      dwFlags := STARTF_USESHOWWINDOW or STARTF_USESTDHANDLES;
      wShowWindow := SW_HIDE;
      hStdInput := GetStdHandle(STD_INPUT_HANDLE); // don't redirect stdin
      hStdOutput := StdOutPipeWrite;
      hStdError := StdOutPipeWrite;
    end;
    Handle := CreateProcess(nil, PChar('cmd.exe /C '+CommandLine),
                            nil, nil, True, 0, nil,
                            PChar(WorkDir), SI, PI);
    CloseHandle(StdOutPipeWrite);
    if Handle then
      try
        repeat
          WasOK := ReadFile(StdOutPipeRead, Buffer, 255, BytesRead, nil);
          if BytesRead > 0 then
          begin
            Buffer[BytesRead] := #0;

            OemToAnsi(Buffer, Buffer);
            aLine := WideString(Buffer);
            Lines := Lines + aLine;
            if Assigned(OnLine) then
              OnLine(aLine);
          end;
        until not WasOK or (BytesRead = 0);
        WaitForSingleObject(PI.hProcess, INFINITE);

        GetExitCodeProcess(PI.hProcess, ExitCode);
        Result := True;
      finally
        CloseHandle(PI.hThread);
        CloseHandle(PI.hProcess);
      end;
  finally
    CloseHandle(StdOutPipeRead);
  end;
end;

end.
