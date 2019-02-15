program CompInstall;

uses
  Vcl.Forms,
  UFrm in 'UFrm.pas' {Frm},
  UCmdExecBuffer in 'UCmdExecBuffer.pas',
  UDefinitions in 'UDefinitions.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'Component Installer';
  Application.CreateForm(TFrm, Frm);
  Application.Run;
end.
