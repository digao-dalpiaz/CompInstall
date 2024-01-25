unit UGitHub;

interface

procedure CheckGitHubUpdate(const Repository, CurrentVersion: string);

implementation

uses System.Classes, System.SysUtils, Vcl.Graphics,
  Vcl.Dialogs, System.UITypes, System.IOUtils,
  System.Net.HttpClient, System.JSON, Vcl.ExtActns, System.Zip,
  UFrm, UCommon;

const URL_GITHUB = 'https://api.github.com/repos/%s/releases/latest';

type
  TThCheck = class(TThread)
  protected
    procedure Execute; override;
  private
    Repository: string;
    CurrentVersion: string;

    procedure Check;
    procedure Download(const URL: string);
    procedure Log(const A: string; bBold: Boolean = True; Color: TColor = clBlack);
    procedure CleanFolder;
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
          ' Do you want to update it automatically?'+#13+#13+
          'Warning: All content in the component''s folder and subfolders will be deleted.',
          [tag_version]), mtInformation, mbYesNo, 0) = mrYes;
      end);

    if Confirm then
      Download(tag_zip);
  end else
    Log('Your version is already updated.', True, clGreen);
end;

procedure TThCheck.Download(const URL: string);
var
  Dw: TDownLoadURL;
  TmpFile: string;
  Z: TZipFile;
  ZPath, ZFile, ZFileNormalized: string;
begin
  Log('Cleaning component folder...');
  CleanFolder;

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

procedure TThCheck.CleanFolder;
var
  Path, FileName: string;
begin
  for Path in TDirectory.GetFiles(AppDir) do
  begin
    FileName := ExtractFileName(Path);
    if SameText(FileName, ExtractFileName(ParamStr(0))) or
      SameText(FileName, INI_FILE_NAME) then Continue;

    try
      TFile.Delete(Path);
    except
      raise Exception.CreateFmt('Could not delete file %s', [Path]);
    end;
  end;

  for Path in TDirectory.GetDirectories(AppDir) do
  begin
    {$WARN SYMBOL_PLATFORM OFF}
    if TFileAttribute.faHidden in TDirectory.GetAttributes(Path) then Continue; //ignore hidden folders (like .git)
    {$WARN SYMBOL_PLATFORM ON}

    try
      TDirectory.Delete(Path, True);
    except
      raise Exception.CreateFmt('Could not delete folder %s', [Path]);
    end;
  end;
end;

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

end.
