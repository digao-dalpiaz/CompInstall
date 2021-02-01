unit UCommon;

interface

const BDS_KEY = 'Software\Embarcadero\BDS';

const COMPINST_EXE = 'CompInstall.exe';

var AppDir: string;

function HasInList(const Item, List: string): Boolean;
function NormalizeAndRemoveFirstDir(Path: string): string;

implementation

uses System.SysUtils;

function HasInList(const Item, List: string): Boolean;
const SEP = ';';
begin
  //returns if Item is contained in the List splited by SEP character
  Result := Pos(SEP+Item+SEP, SEP+List+SEP)>0;
end;

function NormalizeAndRemoveFirstDir(Path: string): string;
var I: Integer;
begin
  Path := Path.Replace('/', '\');

  I := Path.IndexOf('\');
  if I=-1 then raise Exception.Create('First directory separator not found');

  Result := Path.Remove(0, I+1);
end;

end.
