unit UGitHub;

interface

procedure CheckGitHubUpdate(const Repository, CurrentVersion: string);

implementation

uses System.Classes, System.SysUtils, System.Generics.Collections,
  Vcl.Forms, Vcl.Graphics, Vcl.Dialogs,
  System.UITypes, System.IOUtils, System.StrUtils, System.Math,
  System.Net.HttpClient, System.JSON, Vcl.ExtActns, System.Zip,
  UFrm, UFrmOldFiles, UCommon;

const URL_GITHUB = 'https://api.github.com/repos/%s/releases/latest';

type
  TOldFile = class
  private
    Path: string;
    Folder: Boolean;
  end;
  TOldFiles = class(TObjectList<TOldFile>)
  private
    procedure Add(const Path: string; Folder: Boolean);
  end;

  TThCheck = class(TThread)
  public
    constructor Create(Suspended: Boolean);
    destructor Destroy; override;
  protected
    procedure Execute; override;
  private
    Repository: string;
    CurrentVersion: string;

    OldFiles: TOldFiles;

    procedure Check;
    function ConfirmOldFiles: Boolean;
    procedure Download(const URL: string);
    procedure Log(const A: string; bBold: Boolean = True; Color: TColor = clBlack);
    procedure GetOldFiles;
    procedure DeleteOldFiles;
  end;

constructor TThCheck.Create(Suspended: Boolean);
begin
  inherited;
  OldFiles := TOldFiles.Create;
end;

destructor TThCheck.Destroy;
begin
  OldFiles.Free;
  inherited;
end;

procedure TThCheck.Execute;
begin
  FreeOnTerminate := True;

  try
    Check;
  except
    on E: Exception do
      Log('ERROR: '+E.Message, True, clRed);
  end;

  Synchronize(
    procedure
    begin
      Frm.SetButtons(True);
    end);
end;

procedure TThCheck.Log(const A: string; bBold: Boolean = True; Color: TColor = clBlack);
begin
  Synchronize(
    procedure
    begin
      Frm.Log(A, bBold, Color);
    end);
end;

procedure TThCheck.Check;
var
  H: THTTPClient;
  Res, tag_url, tag_version, tag_zip: string;
  data: TJSONObject;
  Confirm: Boolean;
begin
  Log('Checking for component update...');

  H := THTTPClient.Create;
  try
    Res := H.Get(Format(URL_GITHUB, [Repository])).ContentAsString;
  finally
    H.Free;
  end;

  data := TJSONObject.ParseJSONValue(Res) as TJSONObject;
  try
    if data.GetValue('id')=nil then
      raise Exception.Create('No releases found on GitHub');

    tag_version := data.GetValue('tag_name').Value;
    tag_url := data.GetValue('html_url').Value;
    tag_zip := data.GetValue('zipball_url').Value;
  finally
    data.Free;
  end;

  if tag_version.StartsWith('v', True) then Delete(tag_version, 1, 1);

  if CurrentVersion<>tag_version then
  begin
    Log(Format('New version "%s" available.', [tag_version]), True, clPurple);

    Synchronize(
      procedure
      begin
        Confirm := MessageDlg(Format(
          'There is a new version "%s" of the component available at GitHub.'+
          ' Do you want to update it automatically?',
          [tag_version]), mtInformation, mbYesNo, 0) = mrYes;
      end);

    if Confirm and ConfirmOldFiles then
      Download(tag_zip);

  end else
    Log('Your version is already updated.', True, clGreen);
end;

function TThCheck.ConfirmOldFiles: Boolean;
var
  Confirm: Boolean;
begin
  GetOldFiles;
  if OldFiles.Count=0 then Exit(True); //nothing to delete, auto confirm

  Synchronize(
    procedure
    var
      OldFile: TOldFile;
    begin
      FrmOldFiles := TFrmOldFiles.Create(Application);
      for OldFile in OldFiles do
        with FrmOldFiles.LFiles.Items.Add do
        begin
          Caption := ExtractFileName(OldFile.Path);
          ImageIndex := IfThen(OldFile.Folder, 1, 0);
        end;
      Confirm := FrmOldFiles.ShowModal = mrOk;
      FrmOldFiles.Free;
    end);

  if Confirm then
  begin
    DeleteOldFiles;
    Result := True;
  end else
    Result := False;
end;

procedure TThCheck.GetOldFiles;
var
  Path, FileName: string;
begin
  //directories
  for Path in TDirectory.GetDirectories(AppDir) do
  begin
    {$WARN SYMBOL_PLATFORM OFF}
    if TFileAttribute.faHidden in TDirectory.GetAttributes(Path) then Continue; //ignore hidden folders (like .git)
    {$WARN SYMBOL_PLATFORM ON}

    OldFiles.Add(Path, True);
  end;

  //files
  for Path in TDirectory.GetFiles(AppDir) do
  begin
    FileName := ExtractFileName(Path);
    //skip self EXE and CompInstall.ini
    if SameText(FileName, ExtractFileName(ParamStr(0))) or
      SameText(FileName, INI_FILE_NAME) then Continue;

    OldFiles.Add(Path, False);
  end;
end;

procedure TThCheck.DeleteOldFiles;
var
  OldFile: TOldFile;
begin
  Log('Cleaning component folder...');

  for OldFile in OldFiles do
  begin
    try
      if OldFile.Folder then
        TDirectory.Delete(OldFile.Path, True)
      else
        TFile.Delete(OldFile.Path);
    except
      on E: Exception do
        raise Exception.CreateFmt('Could not delete %s %s: %s',
          [IfThen(OldFile.Folder, 'folder', 'file'), OldFile.Path, E.Message]);
    end;
  end;
end;

procedure TThCheck.Download(const URL: string);
var
  Dw: TDownLoadURL;
  TmpFile: string;
  Z: TZipFile;
  ZPath, ZFile, ZFileNormalized: string;
begin
  Log('Downloading new version...');

  TmpFile := TPath.GetTempFileName;

  Dw := TDownLoadURL.Create(nil);
  try
    Dw.URL := URL;
    Dw.Filename := TmpFile;
    Dw.ExecuteTarget(nil);
  finally
    Dw.Free;
  end;

  Log('Extracting component updates...');

  Z := TZipFile.Create;
  try
    Z.Open(TmpFile, zmRead);

    for ZFile in Z.FileNames do
    begin
      try
        ZFileNormalized := NormalizeAndRemoveFirstDir(ZFile);

        ZPath := TPath.Combine(AppDir, ExtractFilePath(ZFileNormalized));
        if not DirectoryExists(ZPath) then ForceDirectories(ZPath);

        Z.Extract(ZFile, ZPath, False);
      except
        on E: Exception do
          raise Exception.CreateFmt('Error extracting "%s": %s', [ZFile, E.Message]);
      end;
    end;
  finally
    Z.Free;
  end;

  Log('Reloading component info...');
  Synchronize(Frm.LoadDefinitions); //reaload definitions

  Log('Update complete!', True, clGreen);
end;

//

procedure CheckGitHubUpdate(const Repository, CurrentVersion: string);
var
  C: TThCheck;
begin
  if Repository.IsEmpty then Exit;

  Frm.SetButtons(False);

  C := TThCheck.Create(True);
  C.Repository := Repository;
  C.CurrentVersion := CurrentVersion;
  C.Start;
end;

{ TOldFiles }

procedure TOldFiles.Add(const Path: string; Folder: Boolean);
var
  OldFile: TOldFile;
begin
  OldFile := TOldFile.Create;
  OldFile.Path := Path;
  OldFile.Folder := Folder;
  inherited Add(OldFile);
end;

end.
