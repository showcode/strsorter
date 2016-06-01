//
// https://github.com/showcode
//

program Sorter;

uses
  Forms,
  MainFrm in 'MainFrm.pas' {MainForm},
  AppUtils in 'AppUtils.pas',
  BTree in 'BTree.pas',
  ShlDlgs in 'ShlDlgs.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.