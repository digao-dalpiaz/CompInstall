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
  UDelphiVersionCombo in 'UDelphiVersionCombo.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TFrm, Frm);
  Application.Run;
end.
