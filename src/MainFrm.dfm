object MainForm: TMainForm
  Left = 0
  Top = 0
  BorderStyle = bsSingle
  Caption = 'Sorter'
  ClientHeight = 301
  ClientWidth = 421
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  Position = poOwnerFormCenter
  OnClose = FormClose
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 13
  object gbxOptions: TGroupBox
    Left = 8
    Top = 8
    Width = 403
    Height = 169
    TabOrder = 0
    object Label1: TLabel
      Left = 16
      Top = 13
      Width = 82
      Height = 13
      Caption = #1055#1072#1087#1082#1072'-'#1080#1089#1090#1086#1095#1085#1080#1082
    end
    object Label2: TLabel
      Left = 16
      Top = 59
      Width = 80
      Height = 13
      Caption = #1042#1099#1093#1086#1076#1085#1086#1081' '#1092#1072#1081#1083
    end
    object Label4: TLabel
      Left = 16
      Top = 105
      Width = 306
      Height = 13
      Caption = #1052#1072#1082#1089#1080#1084#1072#1083#1100#1085#1086#1077' '#1095#1080#1089#1083#1086' '#1089#1090#1088#1086#1082' '#1074' '#1086#1076#1085#1086#1081' '#1095#1072#1089#1090#1080' '#1074#1099#1093#1086#1076#1085#1086#1075#1086' '#1092#1072#1081#1083#1072
      FocusControl = edtMaxLineCount
    end
    object sbSelectDestination: TSpeedButton
      Left = 311
      Top = 77
      Width = 23
      Height = 22
      Glyph.Data = {
        E6000000424DE60000000000000076000000280000000E0000000E0000000100
        0400000000007000000000000000000000001000000000000000000000000000
        80000080000000808000800000008000800080800000C0C0C000808080000000
        FF0000FF000000FFFF00FF000000FF00FF00FFFF0000FFFFFF00333333333333
        330033333333333333003300000000033300330FFFFFFF033300330F00000F03
        3300330FFFFFFF033300330F00000F033300330FFFFFFF033300330F000FFF03
        3300330FFFFF00033300330F00FF0F033300330FFFFF00333300330000000333
        33003333333333333300}
      OnClick = sbSelectDestinationClick
    end
    object sbSelectSource: TSpeedButton
      Left = 311
      Top = 31
      Width = 23
      Height = 22
      Glyph.Data = {
        E6000000424DE60000000000000076000000280000000E0000000E0000000100
        0400000000007000000000000000000000001000000000000000000000000000
        80000080000000808000800000008000800080800000C0C0C000808080000000
        FF0000FF000000FFFF00FF000000FF00FF00FFFF0000FFFFFF00333333333333
        3300333333333333330030000000000333000BFBFBFBFB0333000FBFBFBFBF03
        33000BFBFBFBFB0333000FBFBFBFBF0333000BFBFBFBFB0333000FBFBFBFBF03
        3300000000000033330030FBFB03333333003800008333333300333333333333
        33003333333333333300}
      OnClick = sbSelectSourceClick
    end
    object sbResetMaxCount: TSpeedButton
      Left = 160
      Top = 124
      Width = 41
      Height = 22
      Caption = #1052#1072#1082#1089'.'
      OnClick = sbResetMaxCountClick
    end
    object edtDest: TEdit
      Left = 16
      Top = 78
      Width = 289
      Height = 21
      TabOrder = 1
    end
    object edtMaxLineCount: TSpinEdit
      Left = 16
      Top = 124
      Width = 121
      Height = 22
      MaxLength = 10
      MaxValue = 0
      MinValue = 0
      TabOrder = 2
      Value = 0
    end
    object edtSource: TEdit
      Left = 16
      Top = 32
      Width = 289
      Height = 21
      TabOrder = 0
    end
  end
  object gbxProgress: TGroupBox
    Left = 8
    Top = 183
    Width = 403
    Height = 82
    TabOrder = 1
    object lblStatus: TLabel
      Left = 16
      Top = 48
      Width = 273
      Height = 13
      AutoSize = False
      Caption = 'lblStatus'
      EllipsisPosition = epPathEllipsis
    end
    object btnStartStop: TButton
      Left = 311
      Top = 16
      Width = 75
      Height = 49
      Action = acStart
      TabOrder = 0
    end
    object ProgressBar: TProgressBar
      Left = 16
      Top = 25
      Width = 273
      Height = 17
      TabOrder = 1
    end
  end
  object ActionList: TActionList
    Left = 352
    Top = 128
    object acStart: TAction
      Caption = 'Start'
      OnExecute = acStartExecute
    end
    object acStop: TAction
      Caption = 'Stop'
      OnExecute = acStopExecute
    end
  end
end
