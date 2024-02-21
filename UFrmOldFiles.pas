unit UFrmOldFiles;

interface

uses Vcl.Forms, Vcl.ExtCtrls, Vcl.StdCtrls, System.ImageList, Vcl.ImgList,
  Vcl.Controls, Vcl.ComCtrls, System.Classes;

type
  TFrmOldFiles = class(TForm)
    LbBig: TLabel;
    LbInfo: TLabel;
    LFiles: TListView;
    IL: TImageList;
    BtnOK: TButton;
    BtnCancel: TButton;
    LbConfirm: TLabel;
    EdConfirm: TEdit;
    BottomLine: TBevel;
    procedure EdConfirmChange(Sender: TObject);
  end;

var
  FrmOldFiles: TFrmOldFiles;

implementation

{$R *.dfm}

procedure TFrmOldFiles.EdConfirmChange(Sender: TObject);
begin
  BtnOK.Enabled := EdConfirm.Text = 'CONFIRM';
end;

end.
