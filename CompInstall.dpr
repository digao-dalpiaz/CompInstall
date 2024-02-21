program CompInstall;

uses
  Vcl.Forms,
  UCmdExecBuffer in 'UCmdExecBuffer.pas',
  UCommon in 'UCommon.pas',
  UDefinitions in 'UDefinitions.pas',
  UDelphiVersionCombo in 'UDelphiVersionCombo.pas',
  UFrm in 'UFrm.pas' {Frm},
  UGitHub in 'UGitHub.pas',
  UProcess in 'UProcess.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TFrm, Frm);
  Application.Run;
end.
