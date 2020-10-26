program CompInstall;

uses
  Vcl.Forms,
  System.SysUtils,
  UFrm in 'UFrm.pas' {Frm},
  UCmdExecBuffer in 'UCmdExecBuffer.pas',
  UDefinitions in 'UDefinitions.pas',
  UGitHub in 'UGitHub.pas',
  UProcess in 'UProcess.pas',
  UCommon in 'UCommon.pas',
  UFrmUnzip in 'UFrmUnzip.pas' {FrmUnzip};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  if not FindCmdLineSwitch('upd') then
    Application.CreateForm(TFrm, Frm)
  else
    Application.CreateForm(TFrmUnzip, FrmUnzip);
  Application.Run;
end.
