unit UFrmUnzip;

interface

uses Vcl.Forms, System.Classes, Vcl.Controls, Vcl.StdCtrls;

type
  TFrmUnzip = class(TForm)
    LbInfo: TLabel;
    procedure FormActivate(Sender: TObject);
  private
    procedure Execute;
  end;

var
  FrmUnzip: TFrmUnzip;

implementation

{$R *.dfm}

uses UCommon,
  System.SysUtils, System.IOUtils, System.Zip,
  Vcl.Dialogs, System.UITypes,
  Winapi.ShellAPI, Winapi.Windows;

procedure TFrmUnzip.FormActivate(Sender: TObject);
begin
  OnActivate := nil;
  Refresh;

  try
    Execute;
  except
    on E: Exception do
      MessageDlg(E.Message, mtError, [mbOK], 0);
  end;
  Close;
end;

procedure TFrmUnzip.Execute;
var
  Dir: string;
  OriginalApp: string;
  I: Integer;
  Z: TZipFile;
  ZFile, ZFileNormalized: string;
begin
  Dir := GetEnvironmentVariable('UPD_PATH');

  if Dir.IsEmpty then
    raise Exception.Create('Component directory is empty');

  if not DirectoryExists(Dir) then
    raise Exception.Create('Component directory does not exist');

  OriginalApp := TPath.Combine(Dir, COMPINST_EXE);

  I := 5;
  while not System.SysUtils.DeleteFile(OriginalApp) do
  begin
    Dec(I);
    if I=0 then raise Exception.Create('Could not delete old Component Installer');
    Sleep(1000);
  end;

  TFile.Copy(Application.ExeName, OriginalApp);

  Z := TZipFile.Create;
  try
    Z.Open(TPath.Combine(ExtractFilePath(Application.ExeName), 'data.zip'), zmRead);

    for ZFile in Z.FileNames do
    begin
      ZFileNormalized := NormalizeAndRemoveFirstDir(ZFile);
      if SameText(ZFileNormalized, COMPINST_EXE) then Continue;
      
      Z.Extract(ZFile, TPath.Combine(Dir, ExtractFilePath(ZFileNormalized)), False);
    end;
  finally
    Z.Free;
  end;

  ShellExecute(0, '', PChar(OriginalApp), '', '', SW_SHOWNORMAL);
end;

end.
