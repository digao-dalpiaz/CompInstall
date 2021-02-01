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
  Dir, BkpDir: string;
  ThisApp: string;
  I: Integer;
  Z: TZipFile;
  ZFile, ZFileNormalized, ZPath: string;
begin
  Dir := GetEnvironmentVariable('UPD_PATH');

  if Dir.IsEmpty then
    raise Exception.Create('Component directory is empty');

  if not DirectoryExists(Dir) then
    raise Exception.Create('Component directory does not exist');

  BkpDir := ExcludeTrailingPathDelimiter(Dir)+'_'+FormatDateTime('yyyymmdd-hhnnss', Now);

  I := 5;
  while not System.SysUtils.RenameFile(Dir, BkpDir) do
  begin
    Dec(I);
    if I=0 then raise Exception.CreateFmt('There are files in use in folder "%s"', [Dir]);
    Sleep(1000);
  end;

  TDirectory.CreateDirectory(Dir);

  Z := TZipFile.Create;
  try
    Z.Open(TPath.Combine(ExtractFilePath(Application.ExeName), 'data.zip'), zmRead);

    for ZFile in Z.FileNames do
    begin
      ZFileNormalized := NormalizeAndRemoveFirstDir(ZFile);

      ZPath := TPath.Combine(Dir, ExtractFilePath(ZFileNormalized));
      if not DirectoryExists(ZPath) then ForceDirectories(ZPath);      

      Z.Extract(ZFile, ZPath, False);
    end;
  finally
    Z.Free;
  end;

  ThisApp := TPath.Combine(Dir, COMPINST_EXE);
  if FileExists(ThisApp) then
    raise Exception.Create('Could not find new Component Install app');

  ShellExecute(0, '', PChar(ThisApp), '', '', SW_SHOWNORMAL);
end;

end.
