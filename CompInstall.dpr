program CompInstall;

uses
  Vcl.Forms,
  UFrm in 'UFrm.pas' {Frm};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'Component Installer';
  Application.CreateForm(TFrm, Frm);
  Application.Run;
end.
