unit gsDBSqueeze_unit;

interface

uses
  Windows, SysUtils, IB, IBDatabase, IBSQL, IBQuery, Classes, gd_ProgressNotifier_unit;

const
  NEWDOCUMENT_NUMBER = '�/�';            // ����� ����� �������� ��� ��� ������
  NEWINVDOCUMENT_NUMBER = '1';           // ����� ����� �������� ��� ���������� ������
  PROIZVOLNYE_TRANSACTION_KEY = 807001;  // AC_TRANSACTION.id WHERE AC_TRANSACTION.name = ������������(��) ��������(�)
  PROIZVOLNYE_TRRECORD_KEY = 807100;     // AC_TRRECORD.id WHERE transactionkey = PROIZVOLNYE_TRANSACTION_KEY
  OSTATKY_ACCOUNT_KEY = 300003;          // AC_ACCOUNT.id WHERE fullname = 00 �������
  HOZOPERATION_DOCTYPE_KEY = 806001;     // gd_documenttype.id WHERE name = ������������� ��������
  MAX_PROGRESS_STEP = 12500;
  PROGRESS_STEP = MAX_PROGRESS_STEP div 100;
  INCLUDE_HIS_PROGRESS_STEP = PROGRESS_STEP*16;

type
  TActivateFlag = (aiActivate, aiDeactivate);

  TOnGetDBPropertiesEvent = procedure(const AProperties: TStringList) of object;
  TOnGetDBSizeEvent = procedure(const ADBSizeStr: String; const ADBSize: Int64) of object;
  TOnGetInfoTestConnectEvent = procedure(const AConnectSuccess: Boolean; const AConnectInfoList: TStringList) of object;
  TOnGetProcStatistics = procedure(const AnGdDoc: String; const AnAcEntry: String; const AnInvMovement: String; const AnInvCard: String) of object;
  TOnGetStatistics = procedure(const AnGdDoc: String; const AnAcEntry: String; const AnInvMovement: String; const AnInvCard: String) of object;
  TOnLogSQLEvent = procedure(const S: String) of object;
  TOnSetItemsCbbEvent = procedure(const ACompanies: TStringList) of object;
  TOnSetDocTypeStringsEvent = procedure(const ADocTypeList: TStringList) of object;
  TOnUsedDBEvent = procedure(const AFunctionKey: Integer; const AState: Integer; const ACallTime: String; const AnErrorMessage: String) of object;
  TOnGetConnectedEvent = procedure(const AConnected: Boolean) of object;

  EgsDBSqueeze = class(Exception);

  TgsDBConnectInfo = record
    DatabaseName: String;
    Host: String;
    Port: Integer;
    UserName: String;
    Password: String;
    CharacterSet: String;
  end;

  TgsDBSqueeze = class(TObject)
  private
    FIBDatabase: TIBDatabase;
    FConnectInfo: TgsDBConnectInfo;
    FDBPageSize: Integer;
    FDBPageBuffers: Integer;

    FBackupFileName: String;
    FRestoreDBName: String;
    FLogFileName: String;

    FAllOurCompaniesSaldo: Boolean;
    FCardFeaturesStr: String;   // c����� �����-��������� ��������� ��������
    FClosingDate: TDateTime;

    FCompanyKey: Integer;
    FDocTypesList: TStringList; // ���� ���������� ��������� �������������
    FDoProcDocTypes: Boolean; // true - ������������ ������ ��������� � ���������� ������, false - ������������ ��� ����� ���������� � ���������� ������
    FDoAccount00Saldo: Boolean;

    FContinueReprocess: Boolean;
    FCreateBackup: Boolean;
    FOnlyCompanySaldo: Boolean;
    FSaveLog: Boolean;
    FDoRebindCards: Boolean; 

    FCurUserContactKey: Integer;
    FEntryAnalyticTypesStr: String;
    FEntryAnalyticsStr: String;        // ������ ���� ������������� ��������
    FOurCompaniesListStr: String;      // ������ �������� �� gd_ourcompany
    FProizvolnyyDocTypeKey: Integer;   // ''������������ ���'' �� gd_documenttype
    FPseudoClientKey: Integer;         // ''������������'' �� gd_contact
    FInvSaldoDoc: Integer;

    FCurrentProgressStep: Integer;

    FInactivBlockTriggers: String;
    FIgnoreTbls: TStringList;
    FCascadeTbls: TStringList;

    //FIsFirstConnect: Boolean;
    FIsProcTablesFinish: Boolean;

    FOnProgressWatch: TProgressWatchEvent;
    FOnGetConnectedEvent: TOnGetConnectedEvent;
    FOnGetDBPropertiesEvent: TOnGetDBPropertiesEvent;
    FOnGetDBSizeEvent: TOnGetDBSizeEvent;
    FOnGetInfoTestConnectEvent: TOnGetInfoTestConnectEvent;
    FOnGetProcStatistics: TOnGetProcStatistics;
    FOnGetStatistics: TOnGetStatistics;
    FOnSetItemsCbbEvent: TOnSetItemsCbbEvent;
    FOnSetDocTypeStringsEvent: TOnSetDocTypeStringsEvent;
    FOnUsedDBEvent: TOnUsedDBEvent;
    FOnLogSQLEvent: TOnLogSQLEvent;

    // ���� �� ������� � UDF-����� �������. Raise EgsDBSqueeze exception, ��� ���������� �������
    procedure FuncTest(const AFuncName: String; const ATr: TIBTransaction);

    function CreateHIS(AnIndex: Integer): Integer;
    function GetCountHIS(AnIndex: Integer): Integer;
    function DestroyHIS(AnIndex: Integer): Integer;
    function GetConnected: Boolean;
    // ���������� ��������������� ����� ���������� �������������
    function GetNewID: Integer;

  public
    constructor Create;
    destructor Destroy; override;

    procedure ProgressWatchEvent(const AProgressInfo: TgdProgressInfo);
    procedure ProgressMsgEvent(const AMsg: String; AStepIncrement: Integer = 1);
    procedure ErrorEvent(const AMsg: String; const AProcessName: String = '');
    procedure LogEvent(const AMsg: String);   // �������� � ���

    procedure SetSelectDocTypes(const ADocTypesList: TStringList);

    procedure Connect(ANoGarbageCollect: Boolean; AOffForceWrite: Boolean);
    procedure Disconnect;
    procedure Reconnect(ANoGarbageCollect: Boolean; AOffForceWrite: Boolean);



    // ExecQuery  � ������ � ���
    procedure ExecSqlLogEvent(const AnIBSQL: TIBSQL; const AProcName: String); Overload;
    procedure ExecSqlLogEvent(const AnIBQuery: TIBQuery; const AProcName: String); Overload;

    // �������� �����-����� �� (�������� ������ ��� ��������� ���������� ��)
    procedure BackupDatabase;
    // �������������� �� �����-�����
    procedure RestoreDatabaseFromBackup;

    // �������� ������� ������� ��������� ��������, ����� ��� ��������� ��������� �� ����� ���� ����������
    procedure CreateDBSStateJournal;
    procedure InsertDBSStateJournal(const AFunctionKey: Integer; const AState: Integer; const AErrorMsg: String = '');

    procedure SetFVariables;

    // �������� ����������� ������ ��� ���������
    procedure CreateMetadata;
    // ���������� ��������������� ��������� (PKs, FKs, UNIQs, ��������� �������� � ���������)
    procedure SaveMetadata;

    // ������� �������������� ������
    procedure CalculateAcSaldo;
    // ������������ �������������� ������
    procedure CreateAcEntries;

    // ������� ��������� ��������
    procedure CalculateInvSaldo;
    // ������������ ��������� ��������
    procedure CreateInvSaldo;

    procedure CreateInvBalance;

    procedure SetBlockTriggerActive(const SetActive: Boolean);  // ������������ ��������� ���������� ��������� ���������� (LIKE %BLOCK%)

    procedure PrepareRebindInvCards;
    // ������������ ��������� �������� � ��������
    procedure RebindInvCards;

    // �������� ������� ��� ������
    procedure DeleteOldAcEntryBalance;

    // �������� ���������� ������ � ���������� ��������� �� ���
    procedure CreateHIS_IncludeInHIS;
    procedure DeleteDocuments_DeleteHIS;

    // �������� PKs, FKs, UNIQs, ���������� �������� � ���������
    procedure PrepareDB;
    // �������������� �������������� ��������� (�������� PKs, FKs, UNIQs, ��������� �������� � ���������)
    procedure RestoreDB;

    procedure ClearDBSTables;      ////ClearDBSMetadata
    procedure DropDBSStateJournal;

    procedure GetDBPropertiesEvent;   // �������� ���������� � ��
    procedure GetDBSizeEvent;         // �������� ������ ����� ��
    procedure GetInfoTestConnectEvent;// �������� ������ ������� � ���������� ������������ ������ (�������� ���)
    procedure GetProcStatisticsEvent; // �������� ���-�� ������� ��� ��������� � GD_DOCUMENT, AC_ENTRY, INV_MOVEMENT
    procedure GetStatisticsEvent;     // �������� ������� ���-�� ������� � GD_DOCUMENT, AC_ENTRY, INV_MOVEMENT
    procedure SetItemsCbbEvent;       // ��������� ������ our companies ��� ComboBox
    procedure SetDocTypeStringsEvent; // ��������� ������ ����� ���������� ��� StringGrid
    procedure UsedDBEvent; // �� ��� ����� �������������� ���� ����������, ������� ������ ��� ������� ���������� ��������� ���� ������ ������ ������������

    property ConnectInfo: TgsDBConnectInfo read FConnectInfo          write FConnectInfo;
    property AllOurCompaniesSaldo: Boolean read FAllOurCompaniesSaldo write FAllOurCompaniesSaldo;
    property BackupFileName: String        read FBackupFileName       write FBackupFileName;
    property RestoreDBName: String         read FRestoreDBName        write FRestoreDBName;
    property ClosingDate: TDateTime        read FClosingDate          write FClosingDate;
    property CompanyKey: Integer           read FCompanyKey           write FCompanyKey;
    property Connected: Boolean            read GetConnected;
    property DoAccount00Saldo: Boolean     read FDoAccount00Saldo     write FDoAccount00Saldo;
    property DocTypesList: TStringList     read FDocTypesList         write SetSelectDocTypes;
    property DoProcDocTypes: Boolean       read FDoProcDocTypes       write FDoProcDocTypes;
    property CreateBackup: Boolean         read FCreateBackup         write FCreateBackup;
    property LogFileName: String           read FLogFileName          write FLogFileName;
    property OnProgressWatch: TProgressWatchEvent
      read FOnProgressWatch            write FOnProgressWatch;
    property OnGetConnectedEvent: TOnGetConnectedEvent
      read FOnGetConnectedEvent        write FOnGetConnectedEvent;
    property OnGetDBPropertiesEvent: TOnGetDBPropertiesEvent
      read FOnGetDBPropertiesEvent     write FOnGetDBPropertiesEvent;
    property OnGetDBSizeEvent: TOnGetDBSizeEvent  read FOnGetDBSizeEvent write FOnGetDBSizeEvent;
    property OnGetInfoTestConnectEvent: TOnGetInfoTestConnectEvent
      read FOnGetInfoTestConnectEvent  write FOnGetInfoTestConnectEvent;
    property OnGetProcStatistics: TOnGetProcStatistics
      read FOnGetProcStatistics        write FOnGetProcStatistics;
    property OnGetStatistics: TOnGetStatistics    read FOnGetStatistics  write FOnGetStatistics;
    property OnLogSQLEvent: TOnLogSQLEvent        read FOnLogSQLEvent    write FOnLogSQLEvent;
    property OnlyCompanySaldo: Boolean            read FOnlyCompanySaldo write FOnlyCompanySaldo;

    property OnSetItemsCbbEvent: TOnSetItemsCbbEvent
      read FOnSetItemsCbbEvent         write FOnSetItemsCbbEvent;
    property OnSetDocTypeStringsEvent: TOnSetDocTypeStringsEvent
      read FOnSetDocTypeStringsEvent   write FOnSetDocTypeStringsEvent;
    property OnUsedDBEvent: TOnUsedDBEvent read FOnUsedDBEvent     write FOnUsedDBEvent;
    property SaveLog: Boolean              read FSaveLog           write FSaveLog;
    property ContinueReprocess: Boolean    read FContinueReprocess write FContinueReprocess;
  end;

implementation

uses
  mdf_MetaData_unit, gdcInvDocument_unit, contnrs, IBServices, Messages, IBDatabaseInfo;

{ TgsDBSqueeze }

constructor TgsDBSqueeze.Create;
begin
  inherited;

  FIBDatabase := TIBDatabase.Create(nil);

  

  FIgnoreTbls := TStringList.Create;
  FCascadeTbls := TStringList.Create;
  FCurrentProgressStep := 0;
end;

destructor TgsDBSqueeze.Destroy;
begin
  if Connected then
    Disconnect;
  FIBDatabase.Free;
  FIgnoreTbls.Free;
  FCascadeTbls.Free;
  if Assigned(FDocTypesList) then
    FDocTypesList.Free;

  inherited;
end;

procedure TgsDBSqueeze.SetSelectDocTypes(const ADocTypesList: TStringList);
begin
  if not Assigned(FDocTypesList) then
    FDocTypesList := TStringList.Create
  else
    FDocTypesList.Clear;
  FDocTypesList.Text := ADocTypesList.Text;
end;

procedure TgsDBSqueeze.Connect(ANoGarbageCollect: Boolean; AOffForceWrite: Boolean);
begin
  if not FIBDatabase.Connected then
  begin
    {if FIsFirstConnect then
    begin
      GetDBSizeEvent;
      FIsFirstConnect := False;
    end; }

    if FConnectInfo.Port <> 0 then
      FIBDatabase.DatabaseName := FConnectInfo.Host + '/' + IntToStr(FConnectInfo.Port) + ':' + FConnectInfo.DatabaseName
    else
      FIBDatabase.DatabaseName := FConnectInfo.Host + ':' + FConnectInfo.DatabaseName;

    FIBDatabase.LoginPrompt := False;
    FIBDatabase.Params.CommaText :=
      'user_name=' + FConnectInfo.UserName + ',' +
      'password=' + FConnectInfo.Password + ',' +
      'lc_ctype=' + FConnectInfo.CharacterSet;
    if ANoGarbageCollect then
      FIBDatabase.Params.Append('no_garbage_collect');
    if AOffForceWrite then
      FIBDatabase.Params.Append('force_write=0');

    FIBDatabase.Connected := True;
    FOnGetConnectedEvent(True);
    LogEvent('Connecting to DB... OK');
  end;
end;

procedure TgsDBSqueeze.Reconnect(ANoGarbageCollect: Boolean; AOffForceWrite: Boolean);
begin
  LogEvent('Reconnecting to DB...');

  if FIBDatabase.Connected then
  begin
    FIBDatabase.Connected := False;
  end;

  if FConnectInfo.Port <> 0 then
      FIBDatabase.DatabaseName := FConnectInfo.Host + '/' + IntToStr(FConnectInfo.Port) + ':' + FConnectInfo.DatabaseName
  else
      FIBDatabase.DatabaseName := FConnectInfo.Host + ':' + FConnectInfo.DatabaseName;

    FIBDatabase.LoginPrompt := False;
    FIBDatabase.Params.CommaText :=
      'user_name=' + FConnectInfo.UserName + ',' +
      'password=' + FConnectInfo.Password + ',' +
      'lc_ctype=' + FConnectInfo.CharacterSet;
    if ANoGarbageCollect then
      FIBDatabase.Params.Append('no_garbage_collect');
    if AOffForceWrite then
      FIBDatabase.Params.Append('force_write=0');

    FIBDatabase.Connected := True;

  LogEvent('Reconnecting to DB... OK');
end;

procedure TgsDBSqueeze.Disconnect;
begin
  if FIBDatabase.Connected then
  begin
    FIBDatabase.Connected := False;
    LogEvent('Disconnecting from DB... OK');
    FOnGetConnectedEvent(False);
  end;
end;

procedure TgsDBSqueeze.BackupDatabase;
var
  BS: TIBBackupService;
  NextLogLine: String;
begin
  LogEvent('Backup DB... ');

  Disconnect;

  BS := TIBBackupService.Create(nil);
  try
    BS.Protocol := Local;
    BS.LoginPrompt := False;
    BS.Params.Clear;
    BS.Params.CommaText :=
      'user_name=' + FConnectInfo.UserName + ',' +
      'password=' + FConnectInfo.Password;
    BS.DatabaseName := FConnectInfo.DatabaseName;
    BS.BackupFile.Clear;
    BS.BackupFile.Add(FBackupFileName);
    BS.Options := [IgnoreChecksums, IgnoreLimbo, NoGarbageCollection];

    BS.Attach;

    try
      if BS.Active then
      begin
        try
          BS.ServiceStart;

          while (not BS.EOF) and (BS.IsServiceRunning) do
          begin
            NextLogLine := BS.GetNextLine;
            if NextLogLine <> '' then
              LogEvent(NextLogLine);
          end;
        except
          on E: Exception do
          begin
            BS.Active := False;
            raise EgsDBSqueeze.Create(E.Message);
          end;
        end;
      end;

      if NextLogLine <> '' then                                    ///TODO �������� � ������������  - �� ������ �������������� ���������
        raise EgsDBSqueeze.Create('Database Backup Error!');
    finally
      if BS.Active then
        BS.Detach;
    end;

    Connect(False, True);
    LogEvent('Backup DB... OK');
  finally
    FreeAndNil(BS);
  end;
end;

procedure TgsDBSqueeze.RestoreDatabaseFromBackup;
var
  RS: TIBRestoreService;
  NextLogLine: String;
begin
  LogEvent('Restore DB from backup... ');

  Disconnect;

  RS := TIBRestoreService.Create(nil);
  try
    RS.Protocol := Local;
    RS.LoginPrompt := False;
    RS.Params.Clear;
    RS.Params.CommaText :=
      'user_name=' + FConnectInfo.UserName + ',' +
      'password=' + FConnectInfo.Password;
    RS.BackupFile.Add(FBackupFileName);
    RS.DatabaseName.Add(FRestoreDBName);
    RS.Options := [Replace];
    RS.PageSize := FDBPageSize;
    RS.PageBuffers := FDBPageBuffers;

    RS.Attach;

    try
      if RS.Active then
      begin
        try
          RS.ServiceStart;

          while (not RS.EOF) and (RS.IsServiceRunning) do
          begin
            NextLogLine := RS.GetNextLine;
            if NextLogLine <> '' then
              LogEvent(NextLogLine);
          end;
        except
          on E: Exception do
          begin
            RS.Active := False;
            raise EgsDBSqueeze.Create(E.Message);
          end;
        end;
      end;

      if NextLogLine <> '' then
        raise EgsDBSqueeze.Create('Database Restore Error!');
    finally
      if RS.Active then
        RS.Detach;
    end;

    Connect(False, True);
    LogEvent('Restore DB from backup... OK');
  finally
    FreeAndNil(RS);
  end;
end;

procedure TgsDBSqueeze.SetFVariables;
var
  q, q2: TIBSQL;
  Tr: TIBTransaction;
begin
  Assert(Connected);

  Tr := TIBTransaction.Create(nil);
  q := TIBSQL.Create(nil);
  q2 := TIBSQL.Create(nil);
  try
    Tr.DefaultDatabase := FIBDatabase;
    Tr.StartTransaction;

    q.Transaction := Tr;
    q2.Transaction := Tr;

    q.SQL.Text :=
      'SELECT gu.contactkey AS CurUserContactKey ' +    #13#10 +
      '  FROM gd_user gu ' +                            #13#10 +
      ' WHERE gu.ibname = CURRENT_USER';
    ExecSqlLogEvent(q, 'SetFVariables');

    if q.EOF then
      raise EgsDBSqueeze.Create('Invalid GD_USER data');
    FCurUserContactKey := q.FieldByName('CurUserContactKey').AsInteger;
    q.Close;


    q.SQL.Text :=
      'SELECT ' +                                                     #13#10 +
      '  TRIM(rf.rdb$field_name) AS UsrFieldName, ' +                           #13#10 +
      '  CASE f.rdb$field_type ' +                                    #13#10 +
      '    WHEN 7 THEN ' +                                            #13#10 +
      '      CASE f.rdb$field_sub_type ' +                            #13#10 +
      '        WHEN 0 THEN '' SMALLINT'' ' +                          #13#10 +
      '        WHEN 1 THEN '' NUMERIC('' || f.rdb$field_precision || '','' || (-f.rdb$field_scale) || '')'' ' +  #13#10 +
      '        WHEN 2 THEN '' DECIMAL(''  || f.rdb$field_precision || '','' || (-f.rdb$field_scale) || '')'' ' + #13#10 +
      '      END ' +                                                  #13#10 +
      '    WHEN 8 THEN ' +                                            #13#10 +
      '      CASE f.rdb$field_sub_type ' +                            #13#10 +
      '        WHEN 0 THEN '' INTEGER'' ' +                           #13#10 +
      '        WHEN 1 THEN '' NUMERIC(''  || f.rdb$field_precision || '','' || (-f.rdb$field_scale) || '')'' ' + #13#10 +
      '        WHEN 2 THEN '' DECIMAL(''  || f.rdb$field_precision || '','' || (-f.rdb$field_scale) || '')'' ' + #13#10 +
      '      END ' +                                                  #13#10 +
      '    WHEN 9 THEN '' QUAD'' ' +                                  #13#10 +
      '    WHEN 10 THEN '' FLOAT'' ' +                                #13#10 +
      '    WHEN 12 THEN '' DATE'' ' +                                 #13#10 +
      '    WHEN 13 THEN '' TIME'' ' +                                 #13#10 +
      '    WHEN 14 THEN '' CHAR('' || (TRUNC(f.rdb$field_length / ch.rdb$bytes_per_character)) || '')'' ' +      #13#10 +
      '    WHEN 16 THEN ' +                                           #13#10 +
      '      CASE f.rdb$field_sub_type ' +                            #13#10 +
      '        WHEN 0 THEN '' BIGINT'' ' +                            #13#10 +
      '        WHEN 1 THEN '' NUMERIC(''  || f.rdb$field_precision || '','' || (-f.rdb$field_scale) || '')'' ' + #13#10 +
      '        WHEN 2 THEN '' DECIMAL(''  || f.rdb$field_precision || '','' || (-f.rdb$field_scale) || '')'' ' + #13#10 +
      '      END ' +                                                  #13#10 +
      '    WHEN 27 THEN '' DOUBLE'' ' +                               #13#10 +
      '    WHEN 35 THEN '' TIMESTAMP'' ' +                            #13#10 +
      '    WHEN 37 THEN '' VARCHAR('' || (TRUNC(f.rdb$field_length / ch.rdb$bytes_per_character)) || '')'' ' +   #13#10 +
      '    WHEN 40 THEN '' CSTRING('' || (TRUNC(f.rdb$field_length / ch.rdb$bytes_per_character)) || '')'' ' +   #13#10 +
      '    WHEN 45 THEN '' BLOB_ID'' ' +                              #13#10 +
      '    WHEN 261 THEN '' BLOB'' ' +                                #13#10 +
      '    ELSE '' RDB$FIELD_TYPE:?'' ' +                             #13#10 +
      '  END  AS UsrFieldType ' +                                        #13#10 +
      'FROM rdb$relation_fields rf ' +                                #13#10 +
      '  JOIN rdb$fields f ON (f.rdb$field_name = rf.rdb$field_source) ' +                                       #13#10 +
      '  LEFT OUTER JOIN rdb$character_sets ch ON (ch.rdb$character_set_id = f.rdb$character_set_id) ' +         #13#10 +
      'WHERE ' +                                                      #13#10 +
      '  rf.rdb$relation_name = ''AC_ACCOUNT'' ' +                    #13#10 +
      '  AND rf.rdb$field_name LIKE ''USR$%'' ' +                     #13#10 +
      '  AND COALESCE(rf.rdb$system_flag, 0) = 0 ';

    {
    q.SQL.Text :=
      'SELECT ' +                                       #13#10 +
      '  TRIM(rf.rdb$field_name) AS UsrField ' +        #13#10 +
      'FROM ' +                                         #13#10 +
      '  rdb$relation_fields rf ' +                     #13#10 +
      'WHERE ' +                                        #13#10 +
      '  rf.rdb$relation_name = ''AC_ACCOUNT'' ' +      #13#10 +
      '  AND rf.rdb$field_name LIKE ''USR$%'' ';    }
    ExecSqlLogEvent(q, 'SetFVariables');

    while not q.EOF do
    begin
      q2.SQL.Text :=
        'SELECT * ' +                                   #13#10 +
        '  FROM RDB$RELATION_FIELDS ' +                 #13#10 +
        ' WHERE rdb$relation_name = ''AC_ENTRY'' ' +    #13#10 +
        '   AND TRIM(rdb$field_name) = :FN ';
      q2.ParamByName('FN').AsString := q.FieldByName('UsrFieldName').AsString;
      ExecSqlLogEvent(q2, 'SetFVariables');
      if not q2.EOF then
      begin
        if FEntryAnalyticsStr > '' then
        begin
          FEntryAnalyticsStr := FEntryAnalyticsStr + ' , ' + q.FieldByName('UsrFieldName').AsString;
          FEntryAnalyticTypesStr := FEntryAnalyticTypesStr + ', ' + q.FieldByName('UsrFieldName').AsString + ' ' + q.FieldByName('UsrFieldType').AsString;
        end
        else begin
          FEntryAnalyticsStr := q.FieldByName('UsrFieldName').AsString;
          FEntryAnalyticTypesStr := q.FieldByName('UsrFieldName').AsString + ' ' + q.FieldByName('UsrFieldType').AsString;
        end;
      end;
      q2.Close;
      q.Next;
    end;
    q.Close;

    q.SQL.Text :=
      'SELECT LIST( ' +                                 #13#10 +
      '  TRIM(rf.rdb$field_name)) AS UsrFieldsList ' +  #13#10 +
      'FROM ' +                                         #13#10 +
      '  rdb$relation_fields rf ' +                     #13#10 +
      'WHERE ' +                                        #13#10 +
      '  rf.rdb$relation_name = ''INV_CARD'' ' +        #13#10 +
      '  AND rf.rdb$field_name LIKE ''USR$%'' ';
    ExecSqlLogEvent(q, 'SetFVariables');

    if not q.EOF then
      FCardFeaturesStr := q.FieldByName('UsrFieldsList').AsString;
    q.Close;

    q.SQL.Text :=
      'SELECT gd.id AS InvDocTypeKey ' +                #13#10 +
      '  FROM GD_DOCUMENTTYPE gd ' +                    #13#10 +
      ' WHERE TRIM(gd.name) = ''������������ ���'' ';
    ExecSqlLogEvent(q, 'CreateInvSaldo');

    if q.EOF then
      raise EgsDBSqueeze.Create('����������� ������ GD_DOCUMENTTYPE.NAME = ''������������ ���''');
    FProizvolnyyDocTypeKey := q.FieldByName('InvDocTypeKey').AsInteger;
    q.Close;  
  
    if FAllOurCompaniesSaldo then
    begin
      q.SQL.Text :=
        'SELECT LIST(companykey) AS OurCompaniesList ' + #13#10 +
        '  FROM gd_ourcompany';
      ExecSqlLogEvent(q, 'CalculateAcSaldo');

      if not q.EOF then
        FOurCompaniesListStr := q.FieldByName('OurCompaniesList').AsString;
      q.Close;
    end;

    q.SQL.Text :=
      'SELECT id ' +                                    #13#10 +
      '  FROM gd_contact ' +                            #13#10 +
      ' WHERE name = ''������������'' ';
    ExecSqlLogEvent(q, 'CreateInvSaldo');
    if q.EOF then // ���� ������������� �� ����������, �� ��������
    begin
      q.Close;
      q.SQL.Text :=
        'SELECT gc.id AS ParentId ' +                   #13#10 +
        '  FROM gd_contact gc ' +                       #13#10 +
        ' WHERE gc.name = ''�����������'' ';
      ExecSqlLogEvent(q, 'CreateInvSaldo');

      FPseudoClientKey := GetNewID;

      q2.SQL.Text :=
        'INSERT INTO GD_CONTACT ( ' +                   #13#10 +
        '  id, ' +                                      #13#10 +
        '  parent, ' +                                  #13#10 +
        '  name, ' +                                    #13#10 +
        '  contacttype, ' +                             #13#10 +
        '  afull, ' +                                   #13#10 +
        '  achag, ' +                                   #13#10 +
        '  aview) ' +                                   #13#10 +
        'VALUES (' +                                    #13#10 +
        '  :id, ' +                                     #13#10 +
        '  :parent, ' +                                 #13#10 +
        '  ''������������'', ' +                        #13#10 +
        '  3, ' +                                       #13#10 +
        '  -1, ' +                                      #13#10 +
        '  -1, ' +                                      #13#10 +
        '  -1)';
      q2.ParamByName('id').AsInteger := FPseudoClientKey;
      q2.ParamByName('parent').AsInteger := q.FieldByName('ParentId').AsInteger;

      ExecSqlLogEvent(q2, 'CreateInvSaldo');
    end
    else
      FPseudoClientKey := q.FieldByName('id').AsInteger;

    FInvSaldoDoc := GetNewID;

    q.Close;
    Tr.Commit;
  finally
    q.Free;
    q2.Free;
    Tr.Free;
  end;
end;

function TgsDBSqueeze.GetNewID: Integer; // return next unique id
var
  q: TIBSQL;
  Tr: TIBTransaction;
begin
  Assert(Connected);
  Result := -1;

  Tr := TIBTransaction.Create(nil);
  q := TIBSQL.Create(nil);
  try
    Tr.DefaultDatabase := FIBDatabase;
    Tr.StartTransaction;
    q.Transaction := Tr;

    q.SQL.Text :=
      'SELECT ' +                                                       #13#10 +
      '  GEN_ID(gd_g_unique, 1) + GEN_ID(gd_g_offset, 0) AS NewID ' +   #13#10 +
      'FROM ' +                                                         #13#10 +
      '  rdb$database ';
    ExecSqlLogEvent(q, 'GetNewID');

    Result := q.FieldByName('NewID').AsInteger;
  finally
    q.Free;
    Tr.Free;
  end;
end;

procedure TgsDBSqueeze.CreateDBSStateJournal;
var
  q: TIBSQL;
  Tr: TIBTransaction;
begin
  Assert(Connected);

  Tr := TIBTransaction.Create(nil);
  q := TIBSQL.Create(nil);
  try
    Tr.DefaultDatabase := FIBDatabase;
    Tr.StartTransaction;
    q.Transaction := Tr;

    if not RelationExist2('DBS_JOURNAL_STATE', Tr) then
    begin
      q.SQL.Text :=
        'CREATE TABLE DBS_JOURNAL_STATE( ' +            #13#10 +
        '  FUNCTIONKEY   INTEGER, ' +                   #13#10 +
        '  STATE         SMALLINT, ' +                  #13#10 +  // 1-�������,0-������, NULL-���������� ���� �������� �������������
        '  CALL_TIME     TIMESTAMP, ' +                 #13#10 +
        '  ERROR_MESSAGE VARCHAR(32000))';
      ExecSqlLogEvent(q, 'CreateDBSStateJournal');
      LogEvent('Table DBS_JOURNAL_STATE has been created.');
    end
    else begin
      LogEvent('Table DBS_JOURNAL_STATE exists.');
      q.SQL.Text:=
        'SELECT COUNT(*) FROM dbs_journal_state';
      ExecSqlLogEvent(q, 'CreateDBSStateJournal');
      if q.RecordCount <> 0 then  // �� ��� �������������� ����������
        UsedDBEvent;
      q.Close;
    end;

    Tr.Commit;
  finally
    q.Free;
    Tr.Free;
  end;
end;

procedure TgsDBSqueeze.InsertDBSStateJournal(
  const AFunctionKey: Integer;
  const AState: Integer;
  const AErrorMsg: String = '');
var
  q: TIBSQL;
  Tr: TIBTransaction;
  NowDT: TDateTime;
begin
  Assert(Connected);
  NowDT := Now;
  Tr := TIBTransaction.Create(nil);
  q := TIBSQL.Create(nil);
  try
    Tr.DefaultDatabase := FIBDatabase;
    Tr.StartTransaction;
    q.Transaction := Tr;

    q.SQL.Text :=
      'INSERT INTO dbs_journal_state ' +                #13#10 +
      'VALUES(:FunctionKey, :State, :Now, :ErrorMsg)';
    q.ParamByName('FunctionKey').AsInteger := AFunctionKey;
    q.ParamByName('State').AsInteger := AState;
    q.ParamByName('Now').AsDateTime := NowDT;
    if AErrorMsg = '' then
      q.ParamByName('ErrorMsg').Clear
    else
      q.ParamByName('ErrorMsg').AsString := AErrorMsg;

    if AErrorMsg <> '' then
      ExecSqlLogEvent(q, 'InsertDBSStateJournal')
    else
      ExecSqlLogEvent(q, 'InsertDBSStateJournal');

    Tr.Commit;
  finally
    q.Free;
    Tr.Free;
  end;
end;

procedure TgsDBSqueeze.DropDBSStateJournal;
var
  q: TIBSQL;
  Tr: TIBTransaction;
begin
  Assert(Connected);
  Tr := TIBTransaction.Create(nil);
  q := TIBSQL.Create(nil);
  try
    Tr.DefaultDatabase := FIBDatabase;
    Tr.StartTransaction;
    q.Transaction := Tr;

    q.SQL.Text :=
      'DROP TABLE dbs_journal_state ';
    ExecSqlLogEvent(q, 'InsertDBSStateJournal');

    Tr.Commit;

    FIsProcTablesFinish := True;
  finally
    q.Free;
    Tr.Free;
  end;
end;

procedure TgsDBSqueeze.CalculateAcSaldo; // ������� �������������� ������ c ����������� � ������� DBS_TMP_AC_SALDO
var
  Tr: TIBTransaction;
  q2, q3: TIBSQL;
  I: Integer;
  TmpStr: String;
  TmpList: TStringList;
  AvailableAnalyticsList: TStringList;  // c����� �������� �������� ��� �����
  OnlyCompanyEntryDoc: Integer;         // �������� ��� �������� ��� ��������� �������� 
  OurCompany_EntryDocList: TStringList; // ������ "��������=�������� ��� ��������"
begin
  LogEvent('Calculating entry balance...');
  Assert(Connected);

  TmpList := TStringList.Create;
  AvailableAnalyticsList := TStringList.Create;
  OurCompany_EntryDocList := TStringList.Create;

  q2 := TIBSQL.Create(nil);
  q3 := TIBSQL.Create(nil);
  Tr := TIBTransaction.Create(nil);
  try
    Tr.DefaultDatabase := FIBDatabase;
    Tr.StartTransaction;
    q2.Transaction := Tr;
    q3.Transaction := Tr;

    if FAllOurCompaniesSaldo then
    begin
      TmpList.Text := StringReplace(FOurCompaniesListStr, ',', #13#10, [rfReplaceAll, rfIgnoreCase]);
      for I := 0 to TmpList.Count-1 do
        OurCompany_EntryDocList.Append(TmpList[I] + '=' + IntToStr(GetNewID));

      TmpList.Clear;  
    end
    else
      OnlyCompanyEntryDoc := GetNewID;

    //-------------------------------------------- ���������� ������ ��� �����
    // �������� �����
    q2.SQL.Text :=
      'SELECT DISTINCT ' +                                      #13#10 +
      '  ae.accountkey AS id, ' +                               #13#10 +
         StringReplace(FEntryAnalyticsStr, 'USR$', 'ac.USR$', [rfReplaceAll, rfIgnoreCase]) + ' ' + #13#10 +
      'FROM AC_ENTRY ae ' +                                     #13#10 +
      '  JOIN AC_ACCOUNT ac ON ae.accountkey = ac.id ' +        #13#10 +
      'WHERE ' +                                                #13#10 +
      '  ae.entrydate < :EntryDate ';
    if FOnlyCompanySaldo then
      q2.SQL.Add(' ' +                                          
        'AND ae.companykey = :CompanyKey ')
    else if FAllOurCompaniesSaldo then
      q2.SQL.Add(' ' +
        'AND ae.companykey IN (' + FOurCompaniesListStr + ') ');

    q2.ParamByName('EntryDate').AsDateTime := FClosingDate;
    if FOnlyCompanySaldo then
      q2.ParamByName('CompanyKey').AsInteger := FCompanyKey;
    
    ExecSqlLogEvent(q2, 'CalculateAcSaldo');

    // ������� � ��������� ������ ��� ������� �����
    while not q2.EOF do 
    begin
      AvailableAnalyticsList.Text := StringReplace(FEntryAnalyticsStr, ',', #13#10, [rfReplaceAll, rfIgnoreCase]);
      // �������� c����� �������� ��������, �� ������� ������� ���� ��� �����
      I := 0;
      while I < AvailableAnalyticsList.Count do     
      begin
        if (q2.FieldByName(Trim(AvailableAnalyticsList[I])).AsInteger = 0) or (q2.FieldByName(Trim(AvailableAnalyticsList[I])).IsNull) then
        begin
          AvailableAnalyticsList.Delete(I);
        end
        else
          Inc(I);
      end;

      // ������� ������ � ������� ��������, �����, ������, ��������
      
      // �������� �� ������
      q3.SQL.Text :=
        'INSERT INTO DBS_TMP_AC_SALDO ( ' +                     #13#10 +
        '  documentkey, masterdockey, ' +                       #13#10 +
        '  accountkey, ' +                                      #13#10 +
        '  accountpart, ' +                                     #13#10 +
        '  recordkey, ' +                                       #13#10 +
        '  recordkey_ostatky, ' +                               #13#10 +
        '  id, ' +                                              #13#10 +
        '  id_ostatky, ' +                                      #13#10 +
        '  companykey, ' +                                      #13#10 +
        '  currkey, ' +                                         #13#10 +
        '  creditncu, ' +                                       #13#10 +
        '  creditcurr, ' +                                      #13#10 +
        '  crediteq, ' +                                        #13#10 +
        '  debitncu, ' +                                        #13#10 +
        '  debitcurr, ' +                                       #13#10 +
        '  debiteq ';
      for I := 0 to AvailableAnalyticsList.Count - 1 do
        q3.SQL.Add(', ' +                                       #13#10 +
          AvailableAnalyticsList[I]);

      q3.SQL.Add(
        ') ' +                                                  #13#10 +
        'SELECT ');                                             // CREDIT
      // documentkey = masterkey
      if FOnlyCompanySaldo then
        TmpStr := ' ' +                                            
          IntToStr(OnlyCompanyEntryDoc)
      else if FAllOurCompaniesSaldo then
      begin                     // documentkey
        TmpStr := ' ' +
          'CASE companykey ';
        for I := 0 to OurCompany_EntryDocList.Count-1 do
        begin
          TmpStr :=  TmpStr + ' ' +
            'WHEN ' + OurCompany_EntryDocList.Names[I] + ' THEN ' + OurCompany_EntryDocList.Values[OurCompany_EntryDocList.Names[I]];
        end;
        TmpStr :=  TmpStr + ' ' +
          'END ';
      end;
      TmpStr :=  TmpStr + ',' + TmpStr + ',';// + masterdocumentkey
      
      q3.SQL.Add(' ' +
        TmpStr +                                                #13#10 +
        '  accountkey, ' +                                      #13#10 +
        '  ''C'', ' +                                           #13#10 +
        '  GEN_ID(gd_g_unique, 1) + GEN_ID(gd_g_offset, 0), ' + #13#10 +
        '  GEN_ID(gd_g_unique, 1) + GEN_ID(gd_g_offset, 0), ' + #13#10 +
        '  GEN_ID(gd_g_unique, 1) + GEN_ID(gd_g_offset, 0), ' + #13#10 +
        '  GEN_ID(gd_g_unique, 1) + GEN_ID(gd_g_offset, 0), ' + #13#10 +
        '  companykey, ' +                                      #13#10 +
        '  currkey, ' +                                         #13#10 +
        '  ABS(SUM(debitncu)  - SUM(creditncu)), ' +            #13#10 +
        '  ABS(SUM(debitcurr) - SUM(creditcurr)), ' +           #13#10 +
        '  ABS(SUM(debiteq)   - SUM(crediteq)), ' +             #13#10 +
        '  CAST(0.0000 AS DECIMAL(15,4)) , ' +                                         #13#10 +
        '  CAST(0.0000 AS DECIMAL(15,4)) , ' +                                         #13#10 +
        '  CAST(0.0000 AS DECIMAL(15,4)) ');
      for I := 0 to AvailableAnalyticsList.Count - 1 do
        q3.SQL.Add(', ' +
           AvailableAnalyticsList[I]);

      q3.SQL.Add(' ' +
        'FROM AC_ENTRY ' +                                      #13#10 +
        'WHERE accountkey = :AccountKey ' +                     #13#10 +
        '  AND entrydate < :EntryDate ');
      if FOnlyCompanySaldo then
        q3.SQL.Add(' ' +                                        #13#10 +
          'AND companykey = :CompanyKey ')
      else if FAllOurCompaniesSaldo then
        q3.SQL.Add(' ' +                                        #13#10 +
          'AND companykey IN (' + FOurCompaniesListStr + ') ');

      q3.SQL.Add(' ' +                                          #13#10 +
        'GROUP BY ' +                                           #13#10 +
        '  accountkey, ' +                                      #13#10 +
        '  companykey, ' +                                      #13#10 +
        '  currkey ');
      for I := 0 to AvailableAnalyticsList.Count - 1 do
        q3.SQL.Add(', ' +                                       #13#10 +
          AvailableAnalyticsList[I]);
      q3.SQL.Add(' ' +                                          #13#10 +
        'HAVING ' +                                             #13#10 +
        '  (SUM(debitncu) - SUM(creditncu)) < CAST(0.0000 AS DECIMAL(15,4)) ' +        #13#10 +
        '   OR (SUM(debitcurr) - SUM(creditcurr)) < CAST(0.0000 AS DECIMAL(15,4)) ' +  #13#10 +
        '   OR (SUM(debiteq)   - SUM(crediteq))   < CAST(0.0000 AS DECIMAL(15,4)) ' +  #13#10 +

        'UNION ALL ' +                                          #13#10 +  

        'SELECT ');                                            // DEBIT
      // documentkey = masterkey
      if FOnlyCompanySaldo then
        TmpStr := ' ' +
          IntToStr(OnlyCompanyEntryDoc) + ',' + IntToStr(OnlyCompanyEntryDoc) + ',';  
      
      q3.SQL.Add(' ' +
        TmpStr +                                                  #13#10 +
          '  accountkey, ' +                                      #13#10 +
          '  ''D'', ' +                                           #13#10 +
          '  GEN_ID(gd_g_unique, 1) + GEN_ID(gd_g_offset, 0), ' + #13#10 +
          '  GEN_ID(gd_g_unique, 1) + GEN_ID(gd_g_offset, 0), ' + #13#10 +
          '  GEN_ID(gd_g_unique, 1) + GEN_ID(gd_g_offset, 0), ' + #13#10 +
          '  GEN_ID(gd_g_unique, 1) + GEN_ID(gd_g_offset, 0), ' + #13#10 +
          '  companykey, ' +                                      #13#10 +
          '  currkey, ' +                                         #13#10 +
          '  CAST(0.0000 AS DECIMAL(15,4)), ' +                   #13#10 +
          '  CAST(0.0000 AS DECIMAL(15,4)), ' +                   #13#10 +
          '  CAST(0.0000 AS DECIMAL(15,4)), ' +                   #13#10 +
          '  ABS(SUM(debitncu)  - SUM(creditncu)), ' +            #13#10 +
          '  ABS(SUM(debitcurr) - SUM(creditcurr)), ' +           #13#10 +
          '  ABS(SUM(debiteq)   - SUM(crediteq)) ');
      for I := 0 to AvailableAnalyticsList.Count - 1 do
        q3.SQL.Add(', ' +                                       #13#10 +
          AvailableAnalyticsList[I]);

      q3.SQL.Add(' ' +                                          #13#10 +
        'FROM AC_ENTRY ' +                                      #13#10 +
        'WHERE accountkey = :AccountKey ' +                     #13#10 +
        '  AND entrydate < :EntryDate ');
      if FOnlyCompanySaldo then
        q3.SQL.Add(' ' +                                        #13#10 +
          'AND companykey = :CompanyKey ')
      else if FAllOurCompaniesSaldo then
        q3.SQL.Add(' ' +                                        #13#10 +
          'AND companykey IN (' + FOurCompaniesListStr + ') ');
      q3.SQL.Add(' ' +                                          #13#10 +
        'GROUP BY ' +                                           #13#10 +
        '  accountkey, ' +                                      #13#10 +
        '  companykey, ' +                                      #13#10 +
        '  currkey ');
      for I := 0 to AvailableAnalyticsList.Count - 1 do
        q3.SQL.Add(', ' +                                       #13#10 +
          AvailableAnalyticsList[I]);
      q3.SQL.Add(' ' +                                          #13#10 +
        'HAVING ' +                                             #13#10 +
        '  (SUM(debitncu) - SUM(creditncu)) > CAST(0.0000 AS DECIMAL(15,4)) ' +        #13#10 +
        '   OR (SUM(debitcurr) - SUM(creditcurr)) > CAST(0.0000 AS DECIMAL(15,4)) ' +  #13#10 +
        '   OR (SUM(debiteq)   - SUM(crediteq))   > CAST(0.0000 AS DECIMAL(15,4)) '); 

      q3.ParamByName('AccountKey').AsInteger := q2.FieldByName('id').AsInteger;
      q3.ParamByName('EntryDate').AsDateTime := FClosingDate;
      if FOnlyCompanySaldo then
        q3.ParamByName('CompanyKey').AsInteger := FCompanyKey;
      
      ExecSqlLogEvent(q3, 'CalculateAcSaldo');

      AvailableAnalyticsList.Clear;
      q3.Close;

      q2.Next;
    end;
    
    //�������� �� ����� '00 �������' ��� �������� �������
    Tr.Commit;
    q2.Close;
  finally
    q2.Free;
    q3.Free;
    Tr.Free;
    AvailableAnalyticsList.Free;
    OurCompany_EntryDocList.Free;
    TmpList.Free;
  end;
  LogEvent('Calculating entry balance... OK');
end;

procedure TgsDBSqueeze.DeleteOldAcEntryBalance; // �������� ������� �������������� ������
const
  IB_DATE_DELTA = 15018; // ������� � ���� ����� "��������" ������ Delphi � InterBase
var
  q: TIBSQL;
  Tr: TIBTransaction;
  CalculatedBalanceDate: TDateTime; // �������� ���������� � ����� ���������� �������� ENTRY BALANCE
begin
  LogEvent('Deleting old entries balance...');
  Assert(Connected);

  q := TIBSQL.Create(nil);
  Tr := TIBTransaction.Create(nil);
  try
    Tr.DefaultDatabase := FIBDatabase;
    Tr.StartTransaction;

    q.Transaction := Tr;


    if RelationExist2('AC_ENTRY_BALANCE', Tr) then
    begin
      q.SQL.Text := 
        'SELECT ' +                                             #13#10 +
        '  rdb$generator_name ' +                               #13#10 +
        'FROM ' +                                               #13#10 +
        '  rdb$generators ' +                                   #13#10 +
        'WHERE ' +                                              #13#10 +
        '  rdb$generator_name = ''GD_G_ENTRY_BALANCE_DATE''';
      ExecSqlLogEvent(q, 'DeleteOldAcEntryBalance');
      if q.RecordCount <> 0 then
      begin
        q.Close;
        q.SQL.Text :=
          'SELECT ' +                                           #13#10 +
          '  (GEN_ID(gd_g_entry_balance_date, 0) - ' + IntToStr(IB_DATE_DELTA) + ') AS CalculatedBalanceDate ' + #13#10 +
          'FROM rdb$database ';
        ExecSqlLogEvent(q, 'DeleteOldAcEntryBalance');
        if q.FieldByName('CalculatedBalanceDate').AsInteger > 0 then
        begin
          CalculatedBalanceDate := q.FieldByName('CalculatedBalanceDate').AsInteger;

          LogEvent('[test] CalculatedBalanceDate=' + DateTimeToStr(CalculatedBalanceDate));

          if CalculatedBalanceDate < FClosingDate then
          begin
            q.Close;
            q.SQL.Text := 'DELETE FROM ac_entry_balance';
            ExecSqlLogEvent(q, 'DeleteOldAcEntryBalance');

            q.SQL.Text := 'SET GENERATOR gd_g_entry_balance_date TO 0';
            ExecSqlLogEvent(q, 'DeleteOldAcEntryBalance');
          end;
        end;
      end;
    end;

    Tr.Commit;

    LogEvent('Deleting old entries balance... OK');
  finally
    q.Free;
    Tr.Free;
  end;
end;

procedure TgsDBSqueeze.CreateAcEntries;
var
  qInsertAcEntry, qInsertAcRec, q2: TIBSQL;
  Tr: TIBTransaction;
  Id, I: Integer;

  function CountSymbolInStr(ACh: Char; AStr: String): Integer;
  var
    I: Integer;
  begin
    Result := 0;
    for I := 1 to length(AStr) do
      if AStr[I] = ACh then
        Inc(Result);
  end;

begin
  LogEvent('Create entry balance...');
  Assert(Connected);

  qInsertAcRec := TIBSQL.Create(nil);
  qInsertAcEntry := TIBSQL.Create(nil);
  q2 := TIBSQL.Create(nil);
  Tr := TIBTransaction.Create(nil);
  try
    Tr.DefaultDatabase := FIBDatabase;
    Tr.StartTransaction;
    qInsertAcRec.Transaction := Tr;
    qInsertAcEntry.Transaction := Tr;
    q2.Transaction := Tr;

    // ������� ����������.  documentkey=masterdockey
    q2.SQL.Text :=
      'INSERT INTO GD_DOCUMENT ( ' +                                     #13#10 +
      '  id, ' +                                                         #13#10 +
      '  documenttypekey, ' +                                            #13#10 +
      '  number, ' +                                                     #13#10 +
      '  documentdate, ' +                                               #13#10 +
      '  companykey, ' +                                                 #13#10 +
      '  afull, achag, aview, creatorkey, editorkey) ' +                 #13#10 +
      'SELECT DISTINCT ' +                                               #13#10 +
      '  documentkey, ' +                                                #13#10 +
      '  :AccDocTypeKey, ' +                                             #13#10 +
      '  :Number, ' +                                                    #13#10 +
      '  :ClosingDate, ' +                                               #13#10 +
      '  companykey, ' +                                                 #13#10 +
      '  -1, -1, -1, :CurUserContactKey, :CurUserContactKey ' +          #13#10 +
      'FROM DBS_TMP_AC_SALDO ';
    q2.ParamByName('AccDocTypeKey').AsInteger := HOZOPERATION_DOCTYPE_KEY;
    q2.ParamByName('Number').AsString := NEWDOCUMENT_NUMBER;
    q2.ParamByName('ClosingDate').AsDateTime := FClosingDate;
    q2.ParamByName('CurUserContactKey').AsInteger := FCurUserContactKey;

    ExecSqlLogEvent(q2, 'CreateAcEntries');

    // ������� ��������
    qInsertAcRec.SQL.Text :=
      'INSERT INTO AC_RECORD ( ' +                                       #13#10 +
      '  id, ' +                                                         #13#10 +
      '  recorddate, ' +                                                 #13#10 +
      '  trrecordkey, ' +                                                #13#10 +
      '  transactionkey, ' +                                             #13#10 +
      '  documentkey, masterdockey, afull, achag, aview, companykey) ' + #13#10 +
      'SELECT ' +                                                        #13#10 +//DISTINCT ' +                                               
      '  recordkey, ' +                                                  #13#10 +
      '  :ClosingDate, ' +                                               #13#10 +
      '  :ProizvolnyeTrRecordKey, ' +                                    #13#10 +
      '  :ProizvolnyeTransactionKey, ' +                                 #13#10 +
      '  documentkey, masterdockey, -1, -1, -1, companykey ' +           #13#10 +
      'FROM DBS_TMP_AC_SALDO ';
    qInsertAcRec.ParamByName('ClosingDate').AsDateTime := FClosingDate;
    qInsertAcRec.ParamByName('ProizvolnyeTrRecordKey').AsInteger := PROIZVOLNYE_TRRECORD_KEY;
    qInsertAcRec.ParamByName('ProizvolnyeTransactionKey').AsInteger := PROIZVOLNYE_TRANSACTION_KEY;

    ExecSqlLogEvent(qInsertAcRec, 'CreateAcEntries');


    // ������� ��������
    qInsertAcEntry.SQL.Text :=
      'INSERT INTO AC_ENTRY (' +                                #13#10 +
      '  issimple, ' +                                          #13#10 +
      '  id, ' +                                                #13#10 +
      '  entrydate, ' +                                         #13#10 +
      '  recordkey, ' +                                         #13#10 +
      '  transactionkey, ' +                                    #13#10 +
      '  documentkey, masterdockey, companykey, accountkey, ' + #13#10 +
      '  currkey, accountpart, ' +                              #13#10 +
      '  creditncu, creditcurr, crediteq, ' +                   #13#10 +
      '  debitncu, debitcurr, debiteq ';
    if FEntryAnalyticsStr <> '' then
      qInsertAcEntry.SQL.Add(',' +
          FEntryAnalyticsStr);
    qInsertAcEntry.SQL.Add(') ' +
      'SELECT ' +                                               #13#10 +
      '  1, ' +                                                 #13#10 +
      '  id, ' +                                                #13#10 +
      '  :ClosingDate, ' +                                      #13#10 +
      '  recordkey, ' +                                         #13#10 +
      '  :ProizvolnyeTransactionKey, ' +                        #13#10 +
      '  documentkey, masterdockey, companykey, accountkey, ' + #13#10 +
      '  currkey, accountpart, ' +                              #13#10 +
      '  creditncu, creditcurr, crediteq, ' +                   #13#10 +
      '  debitncu, debitcurr, debiteq ');
    if FEntryAnalyticsStr <> '' then
      qInsertAcEntry.SQL.Add(',' +
          FEntryAnalyticsStr);
    qInsertAcEntry.SQL.Add(' ' +
      'FROM DBS_TMP_AC_SALDO ');
    qInsertAcEntry.ParamByName('ClosingDate').AsDateTime := FClosingDate;
    qInsertAcEntry.ParamByName('ProizvolnyeTransactionKey').AsInteger := PROIZVOLNYE_TRANSACTION_KEY;

    ExecSqlLogEvent(qInsertAcEntry, 'CreateAcEntries');

    // �������� �� ����� '00 �������': ��������� ������� ����� �������� �� ������� ����� 00. ���������� ������� ����� �������� �� ������ ����� 00.
    if FDoAccount00Saldo then
    begin
      qInsertAcRec.SQL.Text :=
        'INSERT INTO AC_RECORD ( ' +                                                #13#10 +
        '  id, ' +                                                                  #13#10 +
        '  recorddate, ' +                                                          #13#10 +
        '  trrecordkey, ' +                                                         #13#10 +
        '  transactionkey, ' +                                                      #13#10 +
        '  documentkey, masterdockey, afull, achag, aview, companykey) ' +          #13#10 +
        'SELECT ' + #13#10 + //DISTINCT ' +                                                  
        '  recordkey_ostatky, ' +                                                   #13#10 +
        '  :ClosingDate, ' +                                                        #13#10 +
        '  :ProizvolnyeTrRecordKey, ' +                                             #13#10 +
        '  :ProizvolnyeTransactionKey, ' +                                          #13#10 +
        '  documentkey, masterdockey, -1, -1, -1, companykey ' +                    #13#10 +
        'FROM DBS_TMP_AC_SALDO ';
      qInsertAcRec.ParamByName('ClosingDate').AsDateTime := FClosingDate;
      qInsertAcRec.ParamByName('ProizvolnyeTrRecordKey').AsInteger := PROIZVOLNYE_TRRECORD_KEY;
      qInsertAcRec.ParamByName('ProizvolnyeTransactionKey').AsInteger := PROIZVOLNYE_TRANSACTION_KEY;

      ExecSqlLogEvent(qInsertAcRec, 'CreateAcEntries');

      qInsertAcEntry.SQL.Text :=
        'INSERT INTO AC_ENTRY (' +                                                  #13#10 +
        '  issimple, ' +                                                            #13#10 +
        '  id, ' +                                                                  #13#10 +
        '  entrydate, ' +                                                           #13#10 +
        '  recordkey, ' +                                                           #13#10 +
        '  transactionkey, ' +                                                      #13#10 +
        '  documentkey, masterdockey, companykey, accountkey, ' +                   #13#10 +
        '  currkey, accountpart, ' +                                                #13#10 +
        '  creditncu, creditcurr, crediteq, ' +                                     #13#10 +
        '  debitncu, debitcurr, debiteq ';
      if FEntryAnalyticsStr <> '' then
        qInsertAcEntry.SQL.Add(',' +
            FEntryAnalyticsStr);
      qInsertAcEntry.SQL.Add(') ' +
        'SELECT ' +                                                                 #13#10 +
        '  1, ' +                                                                   #13#10 +
        '  id_ostatky, ' +                                                          #13#10 +
        '  :ClosingDate, ' +                                                        #13#10 +
        '  recordkey_ostatky, ' +                                                   #13#10 +
        '  :ProizvolnyeTransactionKey, ' +                                          #13#10 +
        '  documentkey, masterdockey, companykey, :OstatkyAccountKey, ' +           #13#10 +
        '  currkey, accountpart, ' +                                                #13#10 +
        '  IIF(accountpart = ''C'', CAST(0.0000 AS DECIMAL(15,4)), creditncu), ' +  #13#10 +
        '  IIF(accountpart = ''C'', CAST(0.0000 AS DECIMAL(15,4)), creditcurr), ' + #13#10 +
        '  IIF(accountpart = ''C'', CAST(0.0000 AS DECIMAL(15,4)), crediteq),  ' +  #13#10 +
        '  IIF(accountpart = ''D'', CAST(0.0000 AS DECIMAL(15,4)), debitncu),  ' +  #13#10 +
        '  IIF(accountpart = ''D'', CAST(0.0000 AS DECIMAL(15,4)), debitcurr), ' +  #13#10 +
        '  IIF(accountpart = ''D'', CAST(0.0000 AS DECIMAL(15,4)), debiteq) ');
      if FEntryAnalyticsStr <> '' then
        qInsertAcEntry.SQL.Add(',' +
           FEntryAnalyticsStr);
      qInsertAcEntry.SQL.Add(' ' +
        'FROM DBS_TMP_AC_SALDO ');
      
      qInsertAcEntry.ParamByName('OstatkyAccountKey').AsInteger := OSTATKY_ACCOUNT_KEY;
      qInsertAcEntry.ParamByName('ClosingDate').AsDateTime := FClosingDate;
      qInsertAcEntry.ParamByName('ProizvolnyeTransactionKey').AsInteger := PROIZVOLNYE_TRANSACTION_KEY;

      ExecSqlLogEvent(qInsertAcEntry, 'CreateAcEntries');
    end;     

    Tr.Commit;
  finally
    q2.Free;
    qInsertAcRec.Free;
    qInsertAcEntry.Free;
    Tr.Free;
  end;
  LogEvent('Create entry balance... OK');
end;


procedure TgsDBSqueeze.CalculateInvSaldo;
var
  q, q2: TIBSQL;
  Tr: TIBTransaction;
begin
  LogEvent('Calculating inventory balance...');
  Assert(Connected);

  Tr := TIBTransaction.Create(nil);
  q := TIBSQL.Create(nil);
  q2 := TIBSQL.Create(nil);

  try
    Tr.DefaultDatabase := FIBDatabase;
    Tr.StartTransaction;
    q.Transaction := Tr;
    q2.Transaction := Tr;

    // ������ �� ��������� �������
    q.SQL.Text :=
      'INSERT INTO DBS_TMP_INV_SALDO ' +                        #13#10 +
      'SELECT ' +                                               #13#10 +
     // '  GEN_ID(gd_g_unique, 1) + GEN_ID(gd_g_offset, 0), ' +   #13#10 +   // DOCUMENT ID
     // '  GEN_ID(gd_g_unique, 1) + GEN_ID(gd_g_offset, 0), ' +   #13#10 +   // MASTERDOCKEY
     // '  IIF( ' +
     // '      g_his_has(2, im.cardkey)=1 OR im.cardkey < 147000000, ' +
     // '      im.cardkey, ' +
    //  '      GEN_ID(gd_g_unique, 1) + GEN_ID(gd_g_offset, 0), ' +
    //  '  ), ' +                                                 #13#10 + // ID_CARD
      '  GEN_ID(gd_g_unique, 1) + GEN_ID(gd_g_offset, 0), ' +   #13#10 +   // ID_MOVEMENT_D
      '  GEN_ID(gd_g_unique, 1) + GEN_ID(gd_g_offset, 0), ' +   #13#10 +   // ID_MOVEMENT_C
      '  GEN_ID(gd_g_unique, 1) + GEN_ID(gd_g_offset, 0), ' +   #13#10 +   // MOVEMENTKEY
      '  im.contactkey AS ContactKey, ' +                       #13#10 +
      '  ic.goodkey, ' +                                        #13#10 +
      '  im.cardkey, ' +                                        #13#10 +
      '  ic.companykey, ' +                                     #13#10 +
      '  SUM(im.debit - im.credit) AS Balance ';
  {  if (FCardFeaturesStr <> '') then
      q.SQL.Add(', ' +
        StringReplace(FCardFeaturesStr, 'USR$', 'ic.USR$', [rfReplaceAll, rfIgnoreCase]) + ' '); }
    q.SQL.Add(' ' +                                             #13#10 +
      'FROM inv_movement im ' +                                 #13#10 +
      '  JOIN GD_DOCUMENT doc ON im.documentkey = doc.id ' +    #13#10 +
      '  JOIN INV_CARD ic ON im.cardkey = ic.id ' +             #13#10 +
      'WHERE ' +                                                #13#10 +
      '  im.cardkey > 0 ');                       // ������ ������� � �������, ����� ��� �������������

    if FOnlyCompanySaldo then
      q.SQL.Add(' ' +
        'AND ic.companykey = :CompanyKey ');

    if Assigned(FDocTypesList) then
    begin
      if not FDoProcDocTypes then
        q.SQL.Add(' ' +
          '  AND doc.documenttypekey NOT IN(' + FDocTypesList.CommaText + ') ')
      else
        q.SQL.Add(' ' +
          '  AND doc.documenttypekey IN(' + FDocTypesList.CommaText + ') ');
    end;

    q.SQL.Add(' ' +                                             #13#10 +
      '  AND im.movementdate < :RemainsDate ' +                 #13#10 +
      '  AND im.disabled = 0 ' +                                #13#10 +
      'GROUP BY ' +                                             #13#10 +
      '  im.contactkey, ' +                                     #13#10 +
      '  im.cardkey, ic.goodkey, ' + //TEST'  ic.goodkey, ' +   #13#10 +
      '  ic.companykey ');

    q.ParamByName('RemainsDate').AsDateTime := FClosingDate;

    if FOnlyCompanySaldo then
      q.ParamByName('CompanyKey').AsInteger := FCompanyKey;

    ExecSqlLogEvent(q, 'CalculateInvSaldo');

    Tr.Commit;
    Tr.StartTransaction;

    // ������������ ��������, ����������� ��� ������, �� ��������� ��������
    q2.SQL.Text :=
      'SELECT FIRST(1) s.companykey FROM DBS_TMP_INV_SALDO s';                  ///TODO: ��������
    ExecSqlLogEvent(q2, 'CalculateInvSaldo');

    // SaldoDoc
    q.SQL.Text :=
      'INSERT INTO GD_DOCUMENT (' +                   #13#10 +
      '  id, ' +                                      #13#10 +
      '  documenttypekey, ' +                         #13#10 +
      '  number, '  +                                 #13#10 +
      '  documentdate, ' +                            #13#10 +
      '  companykey, afull, achag, aview, ' +         #13#10 +
      '  creatorkey, editorkey) ' +                   #13#10 +
      'VALUES( '  +                                   #13#10 +
      '  :id, ' +                                     #13#10 +
      '  :documenttypekey, ' +                        #13#10 +
      '  :number, ' +                                 #13#10 +
      '  :documentdate, ' +                           #13#10 +
      '  :companykey, -1, -1, -1, ' +                 #13#10 +
      '  :UserKey, :UserKey) ';

    q.ParamByName('id').AsInteger := FInvSaldoDoc;
    q.ParamByName('documenttypekey').AsInteger := FProizvolnyyDocTypeKey;
    q.ParamByName('documentdate').AsDateTime := FClosingDate;
    q.ParamByName('UserKey').AsInteger := FCurUserContactKey;
    q.ParamByName('number').AsString := NEWINVDOCUMENT_NUMBER;
    q.ParamByName('companykey').AsInteger := q2.FieldByName('companykey').AsInteger;
    ExecSqlLogEvent(q, 'CreateInvSaldo');
    q2.Close;
    
    Tr.Commit;
    Tr.StartTransaction;

    // o�������� ������ �� �������� �������
    q.SQL.Text :=
      'UPDATE inv_card c ' +
      '   SET c.firstdocumentkey = :SaldoDocKey, ' +
      '       c.documentkey = :SaldoDocKey ' +
      ' WHERE EXISTS(SELECT * FROM DBS_TMP_INV_SALDO s WHERE s.cardkey = c.id) ';

    q.ParamByName('SaldoDocKey').AsInteger := FInvSaldoDoc;
    ExecSqlLogEvent(q, 'CalculateInvSaldo');

    Tr.Commit;

//    q.SQL.Text := // �������� ������� ����� �������(�� ���� �� ��� ��� ������ � �� ��� �� �������) - ���� ����������� - ������ ���������, ��� ��� ��������� ��������� ��� ������� � ��������������� �� �� �����
//      'INSERT INTO DBS_TMP_INV_CARD (' +
//      '  id_card, ' +
//      '  new_card, ' +
//      '  goodkey, ' +
//      '  companykey ' +
//      //',  documentkey,  ' +
//      //'  firstdocumentkey ' +
//      ///TODO: ������� ��������� ������� �� ���������
//      ') ' + 
//      'SELECT ' +
//      '  s.id_card, ' +
//      '  GEN_ID(gd_g_unique, 1) + GEN_ID(gd_g_offset, 0), ' +
//      '  s.goodkey, ' +
//      '  s.companykey ' +
//      //', IIF(g_his_has(1, ic.documentkey)=1, ic.documentkey, s.document_key ' +
//     // '  ic.firstdocumentkey ' +
//      'FROM DBS_TMP_INV_SALDO s ' +
//      '  JOIN inv_card ic ON ic.id = s.id_card ' +
//      'WHERE ' +
//      '  g_his_has(2, s.id_card)=0 ' +
//      '  AND s.id_card >= 147000000 ' +
//      'GROUP BY 1, 3, 4';//, 5, 6';//ic.documentkey, ic.firstdocumentkey';
//    ExecSqlLogEvent(q, 'CalculateInvSaldo');
  finally
    q.Free;
    q2.Free;
    Tr.Free;
  end;
  LogEvent('Calculating inventory balance... OK');
end;


procedure TgsDBSqueeze.CreateInvSaldo;
var
  q, q2: TIBSQL;
  Tr: TIBTransaction;
begin
  LogEvent('Create inventory balance...');
  Assert(Connected);

  Tr := TIBTransaction.Create(nil);
  q := TIBSQL.Create(nil);
  q2 := TIBSQL.Create(nil);

  try
    Tr.DefaultDatabase := FIBDatabase;
    Tr.StartTransaction;
    q.Transaction := Tr;
    q2.Transaction := Tr;

    try
//      // create parent docs
//      q.SQL.Text :=
//        'INSERT INTO GD_DOCUMENT (' +                   #13#10 +
//        '  id, ' +                                      #13#10 +
//        '  documenttypekey, ' +                         #13#10 +
//        '  number, '  +                                 #13#10 +
//        '  documentdate, ' +                            #13#10 +
//        '  companykey, afull, achag, aview, ' +         #13#10 +
//        '  creatorkey, editorkey) ' +                   #13#10 +
//        'SELECT ' +                                     #13#10 +
//        '  id_parentdoc, ' +                            #13#10 +
//        '  :InvDocTypeKey, ' +                          #13#10 +
//        '  :Number, ' +                                 #13#10 +
//        '  :ClosingDate, ' +                            #13#10 +
//        '  companykey, -1, -1, -1, ' +                  #13#10 +
//        '  :CurUserContactKey, :CurUserContactKey ' +   #13#10 +
//        'FROM DBS_TMP_INV_SALDO ';
//      q.ParamByName('InvDocTypeKey').AsInteger := FProizvolnyyDocTypeKey;
//      q.ParamByName('ClosingDate').AsDateTime := FClosingDate;
//      q.ParamByName('CurUserContactKey').AsInteger := FCurUserContactKey;
//      q.ParamByName('Number').AsString := NEWINVDOCUMENT_NUMBER;
//
//      ExecSqlLogEvent(q, 'CreateInvSaldo');
//
//      Tr.Commit;
//      Tr.StartTransaction;
//
//    // ������� SaldoDoc
//
//      q.SQL.Text :=
//        'INSERT INTO GD_DOCUMENT (' +                   #13#10 +
//        '  id, ' +                                      #13#10 +
//        '  parent, ' +                                  #13#10 +
//        '  documenttypekey, ' +                         #13#10 +
//        '  number, '  +                                 #13#10 +
//        '  documentdate, ' +                            #13#10 +
//        '  companykey, afull, achag, aview, ' +         #13#10 +
//        '  creatorkey, editorkey) ' +                   #13#10 +
//        'SELECT ' +                                     #13#10 +
//        '  id_document, ' +                             #13#10 +
//        '  id_parentdoc, ' +                            #13#10 +
//        '  :InvDocTypeKey, ' +                          #13#10 +
//        '  :Number, ' +                                 #13#10 +
//        '  :ClosingDate, ' +                            #13#10 +
//        '  companykey, -1, -1, -1, ' +                  #13#10 +
//        '  :CurUserContactKey, :CurUserContactKey ' +   #13#10 +
//        'FROM DBS_TMP_INV_SALDO ';
//      q.ParamByName('InvDocTypeKey').AsInteger := FProizvolnyyDocTypeKey;
//      q.ParamByName('ClosingDate').AsDateTime := FClosingDate;
//      q.ParamByName('CurUserContactKey').AsInteger := FCurUserContactKey;
//      q.ParamByName('Number').AsString := NEWINVDOCUMENT_NUMBER;
//
//      ExecSqlLogEvent(q, 'CreateInvSaldo');
//
//      Tr.Commit;
//      Tr.StartTransaction;
//
//      // �������� ����� ��������� ��������
//
//      q.SQL.Text :=
//        'INSERT INTO INV_CARD (' +                      #13#10 +
//        '  id, ' +                                      #13#10 +
//        '  goodkey, ' +                                 #13#10 +
//        '  documentkey, firstdocumentkey, ' +           #13#10 +
//        '  firstdate, ' +                               #13#10 +
//        '  companykey ';
//     {if (FCardFeaturesStr <> '') then  // ����-��������
//      begin
//        if Pos('USR$INV_ADDLINEKEY', FCardFeaturesStr) <> 0 then
//        begin
//          if Pos('USR$INV_ADDLINEKEY,', FCardFeaturesStr) <> 0 then
//            q.SQL.Add(', ' +                            #13#10 +
//              StringReplace(FCardFeaturesStr, 'USR$INV_ADDLINEKEY,', ' ', [rfReplaceAll, rfIgnoreCase]) +
//              ', USR$INV_ADDLINEKEY ')
//          else
//            q.SQL.Add(', ' +                            #13#10 +
//              FCardFeaturesStr);
//        end
//        else
//          q.SQL.Add(', ' +                              #13#10 +
//            FCardFeaturesStr);
//      end;}
//      q.SQL.Add(
//        ') ' +                                          #13#10 +
//        'SELECT DISTINCT ' +                            #13#10 +
//        '  id_card, ' +                                 #13#10 +
//        '  goodkey, ' +                                 #13#10 +
//        '  id_document, id_document, ' +                #13#10 +
//        '  :ClosingDate, ' +                            #13#10 +
//        '  companykey ');
//      {if (FCardFeaturesStr <> '') then
//      begin
//        if Pos('USR$INV_ADDLINEKEY', FCardFeaturesStr) <> 0 then  // �������� ���� USR$INV_ADDLINEKEY �������� ������ ������� ������� �� �������
//        begin
//          if Pos('USR$INV_ADDLINEKEY,', FCardFeaturesStr) <> 0 then  //�� ��������� � ������ - �������
//            q.SQL.Add(', ' +                            #13#10 +
//              StringReplace(FCardFeaturesStr, 'USR$INV_ADDLINEKEY,', ' ', [rfReplaceAll, rfIgnoreCase]) +
//              ', id_document ')
//          else
//            q.SQL.Add(', ' +                            #13#10 +
//              StringReplace(FCardFeaturesStr, 'USR$INV_ADDLINEKEY', 'id_document ', [rfReplaceAll, rfIgnoreCase]));
//        end
//        else
//          q.SQL.Add(', ' +                              #13#10 +
//            FCardFeaturesStr + ' ');
//      end;}
//      q.SQL.Add(' ' +                                   #13#10 +
//        'FROM  DBS_TMP_INV_SALDO ' +
//        'WHERE g_his_has(2, id_card)=0 AND id_card >= 147000000');
//
//      //q.ParamByName('ClosingDate').AsDateTime := FClosingDate;
//      ExecSqlLogEvent(q, 'CreateInvSaldo');
//
//      Tr.Commit;
//      Tr.StartTransaction;

      // �������� ��������� ����� ���������� ��������

      q.SQL.Text :=
        'INSERT INTO INV_MOVEMENT ( ' +                 #13#10 +
        '  id, goodkey, movementkey, ' +                #13#10 +
        '  movementdate, ' +                            #13#10 +
        '  documentkey, cardkey, ' +                    #13#10 +
        '  debit, ' +                                   #13#10 +
        '  credit, ' +                                  #13#10 +
        '  contactkey) ' +                              #13#10 +
        'SELECT ' +                                     #13#10 +
        '  id_movement_d, goodkey, movementkey, ' +     #13#10 +
        '  :ClosingDate, ' +                            #13#10 +
        '  :SaldoDoc, cardkey, ' +                      #13#10 +
        '  ABS(balance), ' +                            #13#10 +
        '  0, ' +                                       #13#10 +
        '  IIF((balance >= 0), ' +                      #13#10 +
        '    contactkey, ' +                            #13#10 +
        '    :FPseudoClientKey) ' +                     #13#10 +
        'FROM  DBS_TMP_INV_SALDO ';
      q.ParamByName('SaldoDoc').AsInteger := FInvSaldoDoc;
      q.ParamByName('FPseudoClientKey').AsInteger := FPseudoClientKey;
      q.ParamByName('ClosingDate').AsDateTime := FClosingDate;
      ExecSqlLogEvent(q, 'CreateInvSaldo');

      Tr.Commit;
      Tr.StartTransaction;
      // �������� ���������� ����� ���������� ��������

      q.SQL.Text :=                                     #13#10 +
        'INSERT INTO INV_MOVEMENT ( ' +                 #13#10 +
        '  id, goodkey, movementkey, ' +                #13#10 +
        '  movementdate, ' +                            #13#10 +
        '  documentkey, cardkey, ' +                    #13#10 +
        '  debit, ' +                                   #13#10 +
        '  credit, ' +                                  #13#10 +
        '  contactkey) ' +                              #13#10 +
        'SELECT ' +                                     #13#10 +
        '  id_movement_c, goodkey, movementkey, ' +     #13#10 +
        '  :ClosingDate, ' +                            #13#10 +
        '  :SaldoDoc, ' +
        '  cardkey, ' +//
        '  0, ' +                                       #13#10 +
        '  ABS(balance), ' +                            #13#10 +
        '  IIF((balance >= 0), ' +                      #13#10 +
        '    :FPseudoClientKey, ' +                     #13#10 +
        '    contactkey) ' +                            #13#10 +
        'FROM  DBS_TMP_INV_SALDO ';
      q.ParamByName('SaldoDoc').AsInteger := FInvSaldoDoc;
      q.ParamByName('ClosingDate').AsDateTime := FClosingDate;
      q.ParamByName('FPseudoClientKey').AsInteger := FPseudoClientKey;
      q.ParamByName('FPseudoClientKey').AsInteger := FPseudoClientKey;

      ExecSqlLogEvent(q, 'CreateInvSaldo');

      Tr.Commit;

      LogEvent('Create inventory balance... OK');
    except
      on E: Exception do
      begin
        Tr.Rollback;
        raise EgsDBSqueeze.Create(E.Message);
      end;
    end;
  finally
    q.Free;
    q2.Free;
    Tr.Free;
  end;
end;

//procedure TgsDBSqueeze.CreateInvSaldo;
//var
//  q, q2: TIBSQL;
//  Tr: TIBTransaction;
//begin
//  LogEvent('Create inventory balance...');
//  Assert(Connected);
//
//  Tr := TIBTransaction.Create(nil);
//  q := TIBSQL.Create(nil);
//  q2 := TIBSQL.Create(nil);
//
//  try
//    Tr.DefaultDatabase := FIBDatabase;
//    Tr.StartTransaction;
//    q.Transaction := Tr;
//    q2.Transaction := Tr;
//
//    try
//      // create parent docs
//      q.SQL.Text :=
//        'INSERT INTO GD_DOCUMENT (' +                   #13#10 +
//        '  id, ' +                                      #13#10 +
//        '  documenttypekey, ' +                         #13#10 +
//        '  number, '  +                                 #13#10 +
//        '  documentdate, ' +                            #13#10 +
//        '  companykey, afull, achag, aview, ' +         #13#10 +
//        '  creatorkey, editorkey) ' +                   #13#10 +
//        'SELECT ' +                                     #13#10 +
//        '  id_parentdoc, ' +                            #13#10 +
//        '  :InvDocTypeKey, ' +                          #13#10 +
//        '  :Number, ' +                                 #13#10 +
//        '  :ClosingDate, ' +                            #13#10 +
//        '  companykey, -1, -1, -1, ' +                  #13#10 +
//        '  :CurUserContactKey, :CurUserContactKey ' +   #13#10 +
//        'FROM DBS_TMP_INV_SALDO ';
//      q.ParamByName('InvDocTypeKey').AsInteger := FProizvolnyyDocTypeKey;
//      q.ParamByName('ClosingDate').AsDateTime := FClosingDate;
//      q.ParamByName('CurUserContactKey').AsInteger := FCurUserContactKey;
//      q.ParamByName('Number').AsString := NEWINVDOCUMENT_NUMBER;
//
//      ExecSqlLogEvent(q, 'CreateInvSaldo');
//
//      Tr.Commit;
//      Tr.StartTransaction;
//
//    // ������� SaldoDoc
//
//      q.SQL.Text :=
//        'INSERT INTO GD_DOCUMENT (' +                   #13#10 +
//        '  id, ' +                                      #13#10 +
//        '  parent, ' +                                  #13#10 +
//        '  documenttypekey, ' +                         #13#10 +
//        '  number, '  +                                 #13#10 +
//        '  documentdate, ' +                            #13#10 +
//        '  companykey, afull, achag, aview, ' +         #13#10 +
//        '  creatorkey, editorkey) ' +                   #13#10 +
//        'SELECT ' +                                     #13#10 +
//        '  id_document, ' +                             #13#10 +
//        '  id_parentdoc, ' +                            #13#10 +
//        '  :InvDocTypeKey, ' +                          #13#10 +
//        '  :Number, ' +                                 #13#10 +
//        '  :ClosingDate, ' +                            #13#10 +
//        '  companykey, -1, -1, -1, ' +                  #13#10 +
//        '  :CurUserContactKey, :CurUserContactKey ' +   #13#10 +
//        'FROM DBS_TMP_INV_SALDO ';
//      q.ParamByName('InvDocTypeKey').AsInteger := FProizvolnyyDocTypeKey;
//      q.ParamByName('ClosingDate').AsDateTime := FClosingDate;
//      q.ParamByName('CurUserContactKey').AsInteger := FCurUserContactKey;
//      q.ParamByName('Number').AsString := NEWINVDOCUMENT_NUMBER;
//
//      ExecSqlLogEvent(q, 'CreateInvSaldo');
//
//      Tr.Commit;
//      Tr.StartTransaction;
//
//      // �������� ����� ��������� ��������
//
//      q.SQL.Text :=                                     
//        'INSERT INTO INV_CARD (' +                      #13#10 +
//        '  id, ' +                                      #13#10 +
//        '  goodkey, ' +                                 #13#10 +
//        '  documentkey, firstdocumentkey, ' +           #13#10 +
//        '  firstdate, ' +                               #13#10 +
//        '  companykey ';
//     {if (FCardFeaturesStr <> '') then  // ����-��������
//      begin
//        if Pos('USR$INV_ADDLINEKEY', FCardFeaturesStr) <> 0 then
//        begin
//          if Pos('USR$INV_ADDLINEKEY,', FCardFeaturesStr) <> 0 then
//            q.SQL.Add(', ' +                            #13#10 +
//              StringReplace(FCardFeaturesStr, 'USR$INV_ADDLINEKEY,', ' ', [rfReplaceAll, rfIgnoreCase]) +
//              ', USR$INV_ADDLINEKEY ')
//          else
//            q.SQL.Add(', ' +                            #13#10 +
//              FCardFeaturesStr);
//        end
//        else
//          q.SQL.Add(', ' +                              #13#10 +
//            FCardFeaturesStr);
//      end;}
//      q.SQL.Add(
//        ') ' +                                          #13#10 +
//        'SELECT ' +                                     #13#10 +
//        '  new_card, ' +                                #13#10 +
//        '  goodkey, ' +                                 #13#10 +
//        '  147066066, 147066066, ' + //'  documentkey, firstdocumentkey, ' +           #13#10 +
//        '  :ClosingDate, ' +                            #13#10 +
//        '  companykey ');
//      {if (FCardFeaturesStr <> '') then
//      begin
//        if Pos('USR$INV_ADDLINEKEY', FCardFeaturesStr) <> 0 then  // �������� ���� USR$INV_ADDLINEKEY �������� ������ ������� ������� �� �������
//        begin
//          if Pos('USR$INV_ADDLINEKEY,', FCardFeaturesStr) <> 0 then  //�� ��������� � ������ - �������
//            q.SQL.Add(', ' +                            #13#10 +
//              StringReplace(FCardFeaturesStr, 'USR$INV_ADDLINEKEY,', ' ', [rfReplaceAll, rfIgnoreCase]) +
//              ', id_document ')
//          else
//            q.SQL.Add(', ' +                            #13#10 +
//              StringReplace(FCardFeaturesStr, 'USR$INV_ADDLINEKEY', 'id_document ', [rfReplaceAll, rfIgnoreCase]));
//        end
//        else
//          q.SQL.Add(', ' +                              #13#10 +
//            FCardFeaturesStr + ' ');
//      end;}
//      q.SQL.Add(' ' +                                   #13#10 +
//        'FROM  DBS_TMP_INV_CARD ');
//      q.ParamByName('ClosingDate').AsDateTime := FClosingDate;
//
//      ExecSqlLogEvent(q, 'CreateInvSaldo');
//      Tr.Commit;
//      Tr.StartTransaction;
//
//      // �������� ��������� ����� ���������� ��������
//
//      q.SQL.Text :=
//        'INSERT INTO INV_MOVEMENT ( ' +                   #13#10 +
//        '  id, goodkey, movementkey, ' +                  #13#10 +
//        '  movementdate, ' +                              #13#10 +
//        '  documentkey, ' +                               #13#10 +
//        '  cardkey, ' +                                   #13#10 +
//        '  debit, ' +                                     #13#10 +
//        '  credit, ' +                                    #13#10 +
//        '  contactkey) ' +                                #13#10 +
//        'SELECT ' +                                       #13#10 +
//        '  s.id_movement_d, s.goodkey, s.movementkey, ' + #13#10 +
//        '  :ClosingDate, ' +                              #13#10 +
//        '  s.id_document, ' + ///'  IIF(c.id_card IS NULL, s.id_document, c.documentkey), ' + #13#10 +
//        '  IIF(c.id_card IS NULL, s.id_card, c.new_card), ' + #13#10 +
//        '  ABS(s.balance), ' +                            #13#10 +
//        '  0, ' +                                         #13#10 +
//        '  IIF((s.balance >= 0), ' +                      #13#10 +
//        '    s.contactkey, ' +                            #13#10 +
//        '    :FPseudoClientKey) ' +                       #13#10 +
//        'FROM  DBS_TMP_INV_SALDO s ' +                    #13#10 +
//        '  LEFT JOIN DBS_TMP_INV_CARD c ON c.id_card = s.id_card ';
//      q.ParamByName('FPseudoClientKey').AsInteger := FPseudoClientKey;
//      q.ParamByName('ClosingDate').AsDateTime := FClosingDate;
//
//      ExecSqlLogEvent(q, 'CreateInvSaldo');
//
//      // �������� ���������� ����� ���������� ��������
//
//      q.SQL.Text :=                                       #13#10 +
//        'INSERT INTO INV_MOVEMENT ( ' +                   #13#10 +
//        '  id, goodkey, movementkey, ' +                  #13#10 +
//        '  movementdate, ' +                              #13#10 +
//        '  documentkey, ' +                               #13#10 +
//        '  cardkey, ' +                                   #13#10 +
//        '  debit, ' +                                     #13#10 +
//        '  credit, ' +                                    #13#10 +
//        '  contactkey) ' +                                #13#10 +             
//        'SELECT ' +                                       #13#10 +
//        '  s.id_movement_c, s.goodkey, s.movementkey, ' + #13#10 +
//        '  :ClosingDate, ' +                                         #13#10 +
//        '  s.id_document, ' + ///'  IIF(c.id_card IS NULL, s.id_document, c.documentkey), ' + #13#10 +
//        '  IIF(c.id_card IS NULL, s.id_card, c.new_card), ' +        #13#10 +   
//        '  0, ' +                                         #13#10 +
//        '  ABS(s.balance), ' +                            #13#10 +
//        '  IIF((s.balance >= 0), ' +                      #13#10 +
//        '    :FPseudoClientKey, ' +                       #13#10 +
//        '    s.contactkey) ' +                            #13#10 +
//        'FROM  DBS_TMP_INV_SALDO s ' +                    #13#10 +
//        '  LEFT JOIN DBS_TMP_INV_CARD c ON c.id_card = s.id_card ';
//      q.ParamByName('ClosingDate').AsDateTime := FClosingDate;
//      q.ParamByName('FPseudoClientKey').AsInteger := FPseudoClientKey;
//
//      ExecSqlLogEvent(q, 'CreateInvSaldo');
//
//      Tr.Commit;
//
//
//
//      LogEvent('Create inventory balance... OK');
//    except
//      on E: Exception do
//      begin
//        Tr.Rollback;
//        raise EgsDBSqueeze.Create(E.Message);
//      end;
//    end;
//  finally
//    q.Free;
//    q2.Free;
//    Tr.Free;
//  end;
//end;



procedure TgsDBSqueeze.CreateInvBalance;
var
  q: TIBSQL;
  Tr: TIBTransaction;

  function ExistField(FieldName: String; TableName: String): Boolean;
  var
    q: TIBSQL;
    Tr: TIBTransaction;
  begin
    Result := False;
    q := TIBSQL.Create(nil);
    Tr := TIBTransaction.Create(nil);
    try
      Tr.DefaultDatabase := FIBDatabase;
      Tr.StartTransaction;

      q.Transaction := Tr;

      q.SQL.Text :=
        'SELECT * ' +                       #13#10 +
        '  FROM RDB$RELATION_FIELDS ' +     #13#10 +
        ' WHERE RDB$RELATION_NAME = :RN ' + #13#10 +
        '   AND RDB$FIELD_NAME = :FN ';
      q.ParamByName('RN').AsString := UpperCase(Trim(TableName));
      q.ParamByName('FN').AsString := UpperCase(Trim(FieldName));
      ExecSqlLogEvent(q, 'CreateInvBalance');

      Result := not q.EOF;

      Tr.Commit;
    finally
      q.Free;
      Tr.Free;
    end;
  end;

begin
  q := TIBSQL.Create(nil);
  Tr := TIBTransaction.Create(nil);
  try
    Tr.DefaultDatabase := FIBDatabase;
    Tr.StartTransaction;

    q.Transaction := Tr;

    LogEvent('[test] CreateInvBalance...');

    if ExistField('GOODKEY', 'INV_BALANCE') and ExistField('GOODKEY', 'INV_MOVEMENT') then     /// TODO: �� �� ����
      q.SQL.Text :=
        'INSERT INTO inv_balance (' +                      #13#10 +
        '  cardkey, ' +                                    #13#10 +
        '  contactkey, ' +                                 #13#10 +
        '  balance, ' +                                    #13#10 +
        '  goodkey ' +                                     #13#10 +
        ') ' +                                             #13#10 +
        'SELECT ' +                                        #13#10 +
        '  m.cardkey, ' +                                  #13#10 +
        '  m.contactkey, ' +                               #13#10 +
        '  SUM(m.debit - m.credit), ' +                    #13#10 +
        '  m.goodkey ' +                                   #13#10 +
        'FROM inv_movement m ' +                           #13#10 +
        'WHERE m.disabled = 0 ' +                          #13#10 +
        'GROUP BY m.cardkey, m.contactkey, m.goodkey '
    else
      q.SQL.Text :=
        'INSERT INTO inv_balance (' +                      #13#10 +
        '  cardkey, ' +                                    #13#10 +
        '  contactkey, ' +                                 #13#10 +
        '  balance ' +                                     #13#10 +
        ') ' +                                             #13#10 +
        'SELECT ' +                                        #13#10 +
        '  m.cardkey, ' +                                  #13#10 +
        '  m.contactkey, ' +                               #13#10 +
        '  SUM(m.debit - m.credit) ' +                     #13#10 +
        'FROM inv_movement m ' +                           #13#10 +
        'WHERE m.disabled = 0 ' +                          #13#10 +
        'GROUP BY m.cardkey, m.contactkey ';
    ExecSqlLogEvent(q, 'CreateInvBalance');

    Tr.Commit;
    LogEvent('[test] CreateInvBalance');
  finally
    q.Free;
    Tr.Free;
  end;
end;

procedure TgsDBSqueeze.SetBlockTriggerActive(const SetActive: Boolean);
var
  StateStr: String;
  q: TIBSQL;
  q2: TIBSQL;
  Tr: TIBTransaction;
begin
  q := TIBSQL.Create(nil);
  q2 := TIBSQL.Create(nil);
  Tr := TIBTransaction.Create(nil);
  try
    Tr.DefaultDatabase := FIBDatabase;
    Tr.StartTransaction;
    
    q.Transaction := Tr;
    q2.Transaction := Tr;

    if FInactivBlockTriggers = '' then
    begin
      q.SQL.Text :=
        'SELECT ' +                                                   #13#10 +
        '  rdb$trigger_name AS TN ' +                                 #13#10 +
        'FROM ' +                                                     #13#10 +
        '  rdb$triggers ' +                                           #13#10 +
        'WHERE ' +                                                    #13#10 +
        '  rdb$system_flag = 0 ' +                                    #13#10 +
       // '  AND rdb$relation_name = ''AC_ENTRY'' ' +
        '  AND rdb$trigger_name LIKE ''%BLOCK%'' ' +                 #13#10 +
        '  AND rdb$trigger_inactive <> 0 ';                                   ///=1
      ExecSqlLogEvent(q, 'SetBlockTriggerActive');
      while not q.EOF do
      begin
        FInactivBlockTriggers := FInactivBlockTriggers + ' ''' + q.FieldByName('TN').AsString + '''';

        q.Next;
        if not q.EOF then
          FInactivBlockTriggers := FInactivBlockTriggers + ', ';
      end;
      q.Close;
    end;

    FInactivBlockTriggers := FInactivBlockTriggers + ' ';

    q.SQL.Text :=
      'SELECT ' +                                                     #13#10 +
      '  rdb$trigger_name AS TN ' +                                   #13#10 +
      'FROM ' +                                                       #13#10 +
      '  rdb$triggers ' +                                             #13#10 +
      'WHERE ' +                                                      #13#10 +
      '  rdb$system_flag = 0 ' +                                      #13#10 +
      //'  AND rdb$relation_name = ''AC_ENTRY'' ' +
      '  AND rdb$trigger_name LIKE ''%BLOCK%'' ' +                    #13#10 +
      '  AND rdb$trigger_inactive = :IsInactiv ';
    if Trim(FInactivBlockTriggers) <> '' then
    begin
      LogEvent('[test] FInactivBlockTriggers=' + FInactivBlockTriggers);
      q.SQL.Add(
      '  AND rdb$trigger_name NOT IN (' + FInactivBlockTriggers + ')');
    end;

    if SetActive then
    begin
      StateStr := 'ACTIVE';
      q.ParamByName('IsInactiv').AsInteger := 1;
    end
    else begin
      StateStr := 'INACTIVE';
      q.ParamByName('IsInactiv').AsInteger := 0;
    end;
    ExecSqlLogEvent(q, 'SetBlockTriggerActive');

    while not q.EOF do
    begin
      q2.SQL.Text := 'ALTER TRIGGER ' + q.FieldByName('TN').AsString + ' '  + StateStr;
      ExecSqlLogEvent(q2, 'SetBlockTriggerActive');
      q2.Close;
      q.Next;
    end;
    q.Close;

    Tr.Commit;
    Tr.StartTransaction;

    q.SQL.Text :=                                                             ///
      'EXECUTE BLOCK ' +                                                      #13#10 +
      'AS ' +                                                                 #13#10 +
      '  DECLARE VARIABLE TN CHAR(31); ' +                                    #13#10 +
      'BEGIN ' +                                                              #13#10 +
      '  FOR ' +                                                              #13#10 +
      '    SELECT ' +                                                         #13#10 +
      '      rdb$trigger_name ' +                                             #13#10 +
      '    FROM ' +                                                           #13#10 +
      '      rdb$triggers ' +                                                 #13#10 +
      '    WHERE ' +                                                          #13#10 +
      '      rdb$trigger_inactive = 0 ' +                                     #13#10 +
      '     AND rdb$system_flag = 0 ' +                                       #13#10 +
      '     AND rdb$relation_name = ''INV_MOVEMENT'' ' +                      #13#10 +
      '    INTO :TN ' +                                                       #13#10 +
      '  DO ' +                                                               #13#10 +
      '  BEGIN ' +                                                            #13#10 +
      '    EXECUTE STATEMENT ''ALTER TRIGGER '' || :TN || '' ' + StateStr + ' ''; ' + #13#10 +
      '  END ' +                                                                      #13#10 +
      'END';
    ExecSqlLogEvent(q, 'SetBlockTriggerActive');

    Tr.Commit;
  finally
    q.Free;
    q2.Free;
    Tr.Free;
  end;
end;

procedure TgsDBSqueeze.PrepareRebindInvCards;
const
  CardkeyFieldCount = 2;
  CardkeyFieldNames: array[0..CardkeyFieldCount - 1] of String = ('FROMCARDKEY', 'TOCARDKEY');
var
  FieldsList: TStringList;
  PkFieldsList: TStringList;
  RelationName, FieldName: String;
  I, J: Integer;
  Tr: TIBTransaction;
  q3, q4, qInsertGdDoc, qInsertInvCard, qInsertInvMovement, qInsertTmpRebind: TIBSQL;

  CurrentCardKey, CurrentFirstDocKey, CurrentFromContactkey, CurrentToContactkey: Integer;
  NewCardKey, FirstDocumentKey: Integer;
  FirstDate: TDateTime;
  CurrentRelationName: String;
  DocumentParentKey: Integer;
  CardFeaturesList: TStringList;
  NewDocumentKey, NewMovementKey: Integer;
begin
  CreateHIS(0);

  if FDoRebindCards then
  begin
    LogEvent('[test] PrepareRebindInvCards...');

    CardFeaturesList := TStringList.Create;
    PkFieldsList := TStringList.Create;
    FieldsList := TStringList.Create;

    NewCardKey := -1;

    Tr := TIBTransaction.Create(nil);
    q3 := TIBSQL.Create(nil);
    q4 := TIBSQL.Create(nil);
    qInsertTmpRebind := TIBSQL.Create(nil);
    qInsertGdDoc := TIBSQL.Create(nil);
    qInsertInvCard := TIBSQL.Create(nil);
    qInsertInvMovement := TIBSQL.Create(nil);

    try
      Tr.DefaultDatabase := FIBDatabase;
      Tr.StartTransaction;

      q3.Transaction := Tr;
      q4.Transaction := Tr;
      qInsertGdDoc.Transaction := Tr;
      qInsertInvCard.Transaction := Tr;
      qInsertInvMovement.Transaction := Tr;
      qInsertTmpRebind.Transaction := Tr;

      //SetBlockTriggerActive(False);     /// + ���������� ��������� INV_MOVEMENT

      CardFeaturesList.Text := StringReplace(FCardFeaturesStr, ',', #13#10, [rfReplaceAll, rfIgnoreCase]);

      qInsertTmpRebind.SQL.Text :=
        'INSERT INTO DBS_TMP_REBIND_INV_CARDS ' +                 #13#10 +
        '  (cur_cardkey, new_cardkey, cur_first_dockey, first_dockey, first_date, cur_relation_name) ' + #13#10 +
        'VALUES (:CurrentCardKey, :NewCardKey, :CurrentFirstDocKey, :FirstDocumentKey, :FirstDate, :CurrentRelationName) ';
      qInsertTmpRebind.Prepare;

      qInsertGdDoc.SQL.Text :=
        'INSERT INTO GD_DOCUMENT ' +                              #13#10 +
        '  (id, parent, documenttypekey, number, documentdate, companykey, afull, achag, aview, ' + #13#10 +
        'creatorkey, editorkey) ' +                               #13#10 +
        'VALUES ' +                                               #13#10 +
        '  (:id, :parent, :documenttypekey, :number, :documentdate, :companykey, -1, -1, -1, ' + #13#10 + 
        ':userkey, :userkey) ';
      qInsertGdDoc.ParamByName('DOCUMENTDATE').AsDateTime := FClosingDate;
      qInsertGdDoc.Prepare;

      qInsertInvCard.SQL.Text :=
        'INSERT INTO INV_CARD ' +                                 #13#10 +
        '  (id, goodkey, documentkey, firstdocumentkey, firstdate, companykey';
      // ����-��������
      if FCardFeaturesStr <> '' then
        qInsertInvCard.SQL.Add(', ' +                             #13#10 +
          FCardFeaturesStr);
      qInsertInvCard.SQL.Add(' ' +                                #13#10 +
        ') VALUES ' +                                             #13#10 +
        '  (:id, :goodkey, :documentkey, :documentkey, :firstdate, :companykey');
      // ����-��������
      if FCardFeaturesStr <> '' then
        qInsertInvCard.SQL.Add(', ' +                             #13#10 +
          StringReplace(FCardFeaturesStr, 'USR$', ':USR$', [rfReplaceAll, rfIgnoreCase]));
      qInsertInvCard.SQL.Add(
        ')');

      qInsertInvCard.ParamByName('FIRSTDATE').AsDateTime := FClosingDate;                       ///TODO:?
      qInsertInvCard.Prepare;

      qInsertInvMovement.SQL.Text :=
        'INSERT INTO INV_MOVEMENT ' +                             #13#10 +
        '  (id, goodkey, movementkey, movementdate, documentkey, contactkey, cardkey, debit, credit) ' + #13#10 +
        'VALUES ' +                                               #13#10 +
        '  (:id, :goodkey, :movementkey, :movementdate, :documentkey, :contactkey, :cardkey, :debit, :credit) ';
      qInsertInvMovement.ParamByName('MOVEMENTDATE').AsDateTime := FClosingDate;                ///
      qInsertInvMovement.Prepare;

      // �������� ��� ��������, ������� ��������� � �������� �� ����� ��������
      q3.SQL.Text :=
        'SELECT' +                                                #13#10 +
        '  m1.contactkey         AS FromConactKey, ' +            #13#10 +
        '  m.contactkey          AS ToContactKey, ' +             #13#10 +
        '  linerel.relationname, ' +                              #13#10 +
        '  c.id                  AS CardkeyNew, ' +               #13#10 +
        '  c1.id                 AS CardkeyOld,' +                #13#10 +
        '  c.goodkey,' +                                          #13#10 +
        '  c.companykey, ' +                                      #13#10 +
        '  c.firstdocumentkey ' +                                 #13#10 +
        'FROM gd_document d ' +                                   #13#10 +
        '  JOIN GD_DOCUMENTTYPE t ' +                             #13#10 +
        '    ON t.id = d.documenttypekey ' +                      #13#10 +
        '  LEFT JOIN INV_MOVEMENT m ' +                           #13#10 +
        '    ON m.documentkey = d.id ' +                          #13#10 +
        '  LEFT JOIN INV_MOVEMENT m1 ' +                          #13#10 +
        '    ON m1.movementkey = m.movementkey AND m1.id <> m.id ' + #13#10 +
        '  LEFT JOIN INV_CARD c ' +                               #13#10 +
        '    ON c.id = m.cardkey ' +                              #13#10 +
        '  LEFT JOIN INV_CARD c1 ' +                              #13#10 +
        '    ON c1.id = m1.cardkey ' +                            #13#10 +
        '  LEFT JOIN GD_DOCUMENT d_old ' +                        #13#10 +
        '    ON ((d_old.id = c.documentkey) OR (d_old.id = c1.documentkey)) ' + #13#10 +
        '  LEFT JOIN AT_RELATIONS linerel ' +                     #13#10 +
        '    ON linerel.id = t.linerelkey ' +                     #13#10 +
        'WHERE ' +                                                #13#10 +
        '  d.documentdate >= :ClosingDate ' +                     #13#10 +
        '  AND t.classname = ''TgdcInvDocumentType'' ' +          #13#10 +  
        '  AND t.documenttype = ''D'' ' +                         #13#10 +
        '  AND d_old.documentdate < :ClosingDate ';
      q3.ParamByName('ClosingDate').AsDateTime := FClosingDate;
      ExecSqlLogEvent(q3, 'PrepareRebindInvCards');

      FirstDocumentKey := -1;
      FirstDate := FClosingDate;                                 /// TODO: �������� FirstDate
      while not q3.EOF do
      begin
        if q3.FieldByName('CardkeyOld').IsNull then                      /////=>m1 �� ���=> FromConactKey=0
          CurrentCardKey := q3.FieldByName('CardkeyNew').AsInteger
        else
          CurrentCardKey := q3.FieldByName('CardkeyOld').AsInteger;
        CurrentFirstDocKey := q3.FieldByName('firstdocumentkey').AsInteger;
        CurrentFromContactkey := q3.FieldByName('FromConactKey').AsInteger;
        CurrentToContactkey := q3.FieldByName('ToContactKey').AsInteger;
        CurrentRelationName := q3.FieldByName('relationname').AsString;

        if (CurrentFromContactkey > 0) or (CurrentToContactkey > 0) then         //TODO: ��� ������ ��� CurrentFromContactkey = 0
        begin
        // ���� ���������� �������� ��������� �������� ��� ������ ���������

          // ���� �������� ��� ���. ���������
          q4.Close;
          q4.SQL.Text :=                                                        // TODO: �������. Prepare
            {'SELECT FIRST(1) ' +                                        #13#10 +
            '  c.id AS cardkey, ' +                                     #13#10 +
            '  c.firstdocumentkey, ' +                                  #13#10 +
            '  c.firstdate ' +                                          #13#10 +
            'FROM gd_document d ' +                                     #13#10 +
            '  LEFT JOIN INV_MOVEMENT m ' +                             #13#10 +
            '    ON m.documentkey = d.id ' +                            #13#10 +
            '  LEFT JOIN INV_CARD c ' +                                 #13#10 +
            '    ON c.id = m.cardkey ' +                                #13#10 +
            'WHERE ' +                                                  #13#10 +
            '  d.documenttypekey = :DocTypeKey ' +                      #13#10 +
            '  AND d.documentdate = :ClosingDate ' +                    #13#10 +
            '  AND c.goodkey = :GoodKey ' +                             #13#10 +
            '  AND ' +                                                  #13#10 +
            '    ((m.contactkey = :contact1) ' +                        #13#10 +
            '    OR (m.contactkey = :contact2)) ';

          q4.ParamByName('DocTypeKey').AsInteger := FProizvolnyyDocTypeKey;}
            'SELECT FIRST(1) ' +
            '  s.id_card     AS cardkey, ' + 
            '  s.id_document AS firstdocumentkey, ' + 
            '  CAST(:ClosingDate AS DATE)  AS firstdate ' +
            'FROM DBS_TMP_INV_SALDO s ' +
            'WHERE ' +
            '  s.GOODKEY = :GoodKey ' +                             #13#10 +
            '  AND ' +                                              #13#10 +
            '    ((s.contactkey = :contact1) ' +                    #13#10 +
            '    OR (s.contactkey = :contact2)) ';

          q4.ParamByName('ClosingDate').AsDateTime := FClosingDate;
          q4.ParamByName('GoodKey').AsInteger := q3.FieldByName('goodkey').AsInteger;
          q4.ParamByName('CONTACT1').AsInteger := CurrentFromContactkey;
          q4.ParamByName('CONTACT2').AsInteger := CurrentToContactkey;
        
          ExecSqlLogEvent(q4, 'PrepareRebindInvCards');

          if q4.RecordCount > 0 then
          begin
            NewCardKey := q4.FieldByName('CardKey').AsInteger;
            FirstDocumentKey := q4.FieldByName('FirstDocumentKey').AsInteger;
            FirstDate := q4.FieldByName('FirstDate').AsDateTime;
          end
          else //// �� ����� �������������� 
            NewCardKey := -1;
    {      else begin 
        
            // ����� ������� �������� �������� �������, ��������������� ����� ����� �� ��������� �� ��������

            DocumentParentKey := GetNewID;
            qInsertGdDoc.ParamByName('ID').AsInteger :=  DocumentParentKey;
            qInsertGdDoc.ParamByName('PARENT').Clear;
            qInsertGdDoc.ParamByName('DOCUMENTTYPEKEY').AsInteger := FProizvolnyyDocTypeKey;
            qInsertGdDoc.ParamByName('COMPANYKEY').AsInteger := q3.FieldByName('COMPANYKEY').AsInteger;
            qInsertGdDoc.ParamByName('USERKEY').AsInteger := FCurUserContactKey;
            qInsertGdDoc.ParamByName('NUMBER').AsString := NEWINVDOCUMENT_NUMBER;

            ExecSqlLogEvent(qInsertGdDoc, 'PrepareRebindInvCards');
  /////////////
            NewDocumentKey := GetNewID;

            qInsertGdDoc.ParamByName('ID').AsInteger := NewDocumentKey;
            qInsertGdDoc.ParamByName('DOCUMENTTYPEKEY').AsInteger := FProizvolnyyDocTypeKey;
            qInsertGdDoc.ParamByName('PARENT').AsInteger := DocumentParentKey;
            qInsertGdDoc.ParamByName('COMPANYKEY').AsInteger := q3.FieldByName('companykey').AsInteger;
            qInsertGdDoc.ParamByName('USERKEY').AsInteger := FCurUserContactKey;
            qInsertGdDoc.ParamByName('NUMBER').AsString := NEWINVDOCUMENT_NUMBER;
          
            ExecSqlLogEvent(qInsertGdDoc, 'PrepareRebindInvCards');

            NewCardKey := GetNewID;
      
            // �������� ����� ��������� ��������

            qInsertInvCard.ParamByName('ID').AsInteger := NewCardKey;
            qInsertInvCard.ParamByName('GOODKEY').AsInteger := q3.FieldByName('goodkey').AsInteger;
            qInsertInvCard.ParamByName('DOCUMENTKEY').AsInteger := NewDocumentKey;
            qInsertInvCard.ParamByName('COMPANYKEY').AsInteger := q3.FieldByName('companykey').AsInteger;

            for I := 0 to CardFeaturesList.Count - 1 do
            begin
              if Trim(CardFeaturesList[I]) <> 'USR$INV_ADDLINEKEY' then
                qInsertInvCard.ParamByName(Trim(CardFeaturesList[I])).Clear
              else // �������� ���� USR$INV_ADDLINEKEY �������� ������ ������� ������� �� �������
                qInsertInvCard.ParamByName('USR$INV_ADDLINEKEY').AsInteger := NewDocumentKey;
            end;

            ExecSqlLogEvent(qInsertInvCard, 'PrepareRebindInvCards');
          
            NewMovementKey := GetNewID;

            // �������� ��������� ����� ���������� ��������                                       ///TODO: ERROR! CONTACTKEY=0
            qInsertInvMovement.ParamByName('ID').AsInteger := GetNewID;
            qInsertInvMovement.ParamByName('GOODKEY').AsInteger := q3.FieldByName('goodkey').AsInteger;
            qInsertInvMovement.ParamByName('MOVEMENTKEY').AsInteger := NewMovementKey;
            qInsertInvMovement.ParamByName('DOCUMENTKEY').AsInteger := NewDocumentKey;
            //qInsertInvMovement.ParamByName('CONTACTKEY').AsInteger := CurrentFromContactkey; /// �� ���onact?
            if CurrentFromContactkey > 0 then 
              qInsertInvMovement.ParamByName('CONTACTKEY').AsInteger := CurrentFromContactkey
            else  
              qInsertInvMovement.ParamByName('CONTACTKEY').AsInteger := CurrentToContactkey;  

            qInsertInvMovement.ParamByName('CARDKEY').AsInteger := NewCardKey;
            qInsertInvMovement.ParamByName('DEBIT').AsCurrency := 0;
            qInsertInvMovement.ParamByName('CREDIT').AsCurrency := 0;
      
            ExecSqlLogEvent(qInsertInvMovement, 'PrepareRebindInvCards');

            // �������� ���������� ����� ���������� ��������
            qInsertInvMovement.ParamByName('ID').AsInteger := GetNewID;
            qInsertInvMovement.ParamByName('GOODKEY').AsInteger := q3.FieldByName('goodkey').AsInteger;
            qInsertInvMovement.ParamByName('MOVEMENTKEY').AsInteger := NewMovementKey;
            qInsertInvMovement.ParamByName('DOCUMENTKEY').AsInteger := NewDocumentKey;
            //qInsertInvMovement.ParamByName('CONTACTKEY').AsInteger := CurrentFromContactkey;
            if CurrentFromContactkey > 0 then 
              qInsertInvMovement.ParamByName('CONTACTKEY').AsInteger := CurrentFromContactkey
            else  
              qInsertInvMovement.ParamByName('CONTACTKEY').AsInteger := CurrentToContactkey;  

            qInsertInvMovement.ParamByName('CARDKEY').AsInteger := NewCardKey;
            qInsertInvMovement.ParamByName('DEBIT').AsCurrency := 0;
            qInsertInvMovement.ParamByName('CREDIT').AsCurrency := 0;

            ExecSqlLogEvent(qInsertInvMovement, 'PrepareRebindInvCards');
  ////////////////////
          end;}
          q4.Close;
        end
        else begin
          // ���� ���������� �������� ��� ������ ���������                             
          q4.SQL.Text :=
  {          'SELECT FIRST(1) ' +                                          #13#10 +
            '  c.id AS cardkey, ' +                                       #13#10 +
            '  c.firstdocumentkey, ' +                                    #13#10 +
            '  c.firstdate ' +                                            #13#10 +
            'FROM gd_document d ' +                                       #13#10 +
            '  LEFT JOIN INV_MOVEMENT m ' +                               #13#10 +
            '    ON m.documentkey = d.id ' +                              #13#10 +
            '  LEFT JOIN INV_CARD c ' +                                   #13#10 +
            '    ON c.id = m.cardkey ' +                                  #13#10 +
            'WHERE ' +                                                    #13#10 +
            '  d.documenttypekey = :DocTypeKey ' +                        #13#10 +
            '  AND d.documentdate = :ClosingDate ' +                      #13#10 +
            '  AND c.goodkey = :GoodKey ';
          q4.ParamByName('DocTypeKey').AsInteger := FProizvolnyyDocTypeKey;}

            'SELECT FIRST(1) ' +
            '  s.id_card     AS cardkey, ' + 
            '  s.id_document AS firstdocumentkey, ' + 
            '  :ClosingDate  AS firstdate ' +
            'FROM DBS_TMP_INV_SALDO s ' +
            'WHERE ' +                             
            '  s.GOODKEY = :GoodKey ';

          q4.ParamByName('ClosingDate').AsDateTime := FClosingDate;
          q4.ParamByName('GoodKey').AsInteger := q3.FieldByName('GOODKEY').AsInteger;

          ExecSqlLogEvent(q4, 'PrepareRebindInvCards');

          if q4.RecordCount > 0 then
            NewCardKey := q4.FieldByName('CardKey').AsInteger
          else
            NewCardKey := -1;

          q4.Close;
        end;

        qInsertTmpRebind.ParamByName('CurrentCardKey').AsInteger := CurrentCardKey;
        qInsertTmpRebind.ParamByName('NewCardKey').AsInteger := NewCardKey;
        qInsertTmpRebind.ParamByName('CurrentFirstDocKey').AsInteger := CurrentFirstDocKey;
        qInsertTmpRebind.ParamByName('FirstDocumentKey').AsInteger := FirstDocumentKey;
        qInsertTmpRebind.ParamByName('FirstDate').AsDateTime := FirstDate;
        qInsertTmpRebind.ParamByName('CurrentRelationName').AsString := CurrentRelationName;

        ExecSqlLogEvent(qInsertTmpRebind, 'PrepareRebindInvCards');

        q3.Next;
      end;
      q3.Close;
      Tr.Commit;
      Tr.StartTransaction;

      //---------------- ���������� � HIS(0) PK ��� �������, ������� ����� ����� �����������������. ����� ������������ ��� �������� �� �� FK, ������� ����� ����� ��������.

      q3.SQL.Text :=                                          #13#10 +
        'SELECT ' +                                           #13#10 +
        '  g_his_include(0, c.id) ' +                         #13#10 +
        'FROM ' +                                             #13#10 +
        '  inv_card c ' +                                     #13#10 +
        '  JOIN DBS_TMP_REBIND_INV_CARDS tmp ' +              #13#10 +
        '    ON tmp.cur_first_dockey = c.firstdocumentkey ' + #13#10 +
        'WHERE ' +    
        '  tmp.FIRST_DOCKEY > -1 ' +
        '  AND tmp.NEW_CARDKEY > 0 ';
      ExecSqlLogEvent(q3, 'PrepareRebindInvCards');

      q3.Close;
      q3.SQL.Text := 
        'SELECT ' +                                       #13#10 +
        '  g_his_include(0, c.id) ' +                     #13#10 +
        'FROM ' +                                         #13#10 +
        '  inv_card c ' +                                 #13#10 +
        '  JOIN DBS_TMP_REBIND_INV_CARDS tmp ' +          #13#10 +
        '    ON tmp.cur_cardkey = c.parent ' +            #13#10 +
        'WHERE ' +                                        #13#10 +
        '  ( SELECT FIRST(1) m.movementdate ' +           #13#10 +
        '    FROM inv_movement m ' +                      #13#10 +
        '    WHERE m.cardkey = c.id ' +                   #13#10 +
        '    ORDER BY m.movementdate DESC ' +             #13#10 +
        '  ) >= :CloseDate ' +                            #13#10 +
        '  AND tmp.NEW_CARDKEY > 0 ';
      q3.ParamByName('CloseDate').AsDateTime := FClosingDate;
      ExecSqlLogEvent(q3, 'PrepareRebindInvCards');

      q3.Close;
      q3.SQL.Text :=
        'SELECT ' +                                       #13#10 +
        '  g_his_include(0, m.id) ' +                     #13#10 +
        'FROM ' +                                         #13#10 +
        '  inv_movement m ' +                             #13#10 +
        '  JOIN DBS_TMP_REBIND_INV_CARDS tmp ' +          #13#10 +
        '    ON tmp.cur_cardkey = m.cardkey ' +           #13#10 +
        'WHERE ' +                                        #13#10 +
        '  m.movementdate >= :CloseDate ' +               #13#10 +
        '  AND tmp.NEW_CARDKEY > 0 ';
      q3.ParamByName('CloseDate').AsDateTime := FClosingDate;
      ExecSqlLogEvent(q3, 'PrepareRebindInvCards');

      FIgnoreTbls.Add('INV_CARD=PARENT||FIRSTDOCUMENTKEY');
      FIgnoreTbls.Add('INV_MOVEMENT=CARDKEY');

      q3.Close;
      q3.SQL.Text :=
        'SELECT DISTINCT ' +                                      #13#10 +
        '  r.cur_relation_name AS RelationName, ' +               #13#10 +
        '  s.list_fields       AS PkField, ' +                    #13#10 +
        '  rf.rdb$field_name   AS FkField ' +                     #13#10 +
        'FROM dbs_tmp_rebind_inv_cards r ' +                      #13#10 +
        '  JOIN DBS_SUITABLE_TABLES s ' +                         #13#10 +
        '    ON s.relation_name = r.cur_relation_name ' +         #13#10 +
        '  JOIN RDB$RELATION_FIELDS rf ' +                        #13#10 +
        '    ON rf.rdb$relation_name = r.cur_relation_name ' +    #13#10 +
        'WHERE ' +                                                #13#10 +
        '  rf.rdb$field_name IN(''FROMCARDKEY'', ''TOCARDKEY'') ';
      ExecSqlLogEvent(q3, 'PrepareRebindInvCards');

      while not q3.Eof do
      begin
        RelationName := UpperCase(Trim( q3.FieldByName('RelationName').AsString ));
        FieldName := UpperCase(Trim( q3.FieldByName('FkField').AsString ));
        PkFieldsList.Clear;
        PkFieldsList.Text := StringReplace(q3.FieldByName('PkField').AsString, ',', #13#10, [rfReplaceAll, rfIgnoreCase]);

        if FIgnoreTbls.IndexOfName(RelationName) <> -1 then
        begin
          if AnsiPos(FieldName, FIgnoreTbls.Values[RelationName]) = 0 then
            FIgnoreTbls.Values[RelationName] := FIgnoreTbls.Values[RelationName] + '||' + FieldName;
        end
        else   
          FIgnoreTbls.Add(RelationName + '=' + FieldName);

        for I:=0 to PkFieldsList.Count-1 do
        begin
          q4.SQL.Text := Format(
            'SELECT ' +                                             #13#10 +
            '  g_his_include(0, line.%0:s) ' +                      #13#10 +
            'FROM ' +                                               #13#10 +
            '  %1:s line ' +                                        #13#10 +
            '  JOIN DBS_TMP_REBIND_INV_CARDS tmp ' +                #13#10 +
            '    ON tmp.cur_cardkey = line.%2:s ' +                 #13#10 +
            'WHERE ' +                                              #13#10 +
            '  (SELECT doc.documentdate  ' +                        #13#10 +
            '   FROM gd_document doc ' +                            #13#10 +
            '   WHERE doc.id = line.documentkey ' +                 #13#10 +
            '  ) >= :ClosingDate AND tmp.NEW_CARDKEY > 0 ',
            [Trim(PkFieldsList[I]), RelationName, FieldName]);

          q4.ParamByName('ClosingDate').AsDateTime := FClosingDate;
          ExecSqlLogEvent(q4, 'PrepareRebindInvCards');
          q4.Close;
        end;
        q3.Next;
      end;
      q3.Close;
 
      // FK, ������� �� ���� ��������������� ����� �������������, ��� ��� ��� �������� ������ �� ��� ��������� ������.
      // ����������� ��� FK ����� ������������
      LogEvent('[test] FIgnoreTbls: ' + FIgnoreTbls.Text);
      for I:=0 to FIgnoreTbls.Count-1 do
      begin
        FieldsList.Clear;
        FieldsList.Text := StringReplace(FIgnoreTbls.Values[FIgnoreTbls.Names[I]], '||', #13#10, [rfReplaceAll, rfIgnoreCase]);

        for J:=0 to FieldsList.Count-1 do
        begin
          q3.SQL.Text := 
            'INSERT INTO DBS_TMP_FK_CONSTRAINTS ( ' +                       #13#10 +
            '  relation_name, ' +                                           #13#10 +
            '  ref_relation_name, ' +                                       #13#10 +
            '  constraint_name, ' +                                         #13#10 +
            '  list_fields, list_ref_fields, update_rule, delete_rule) ' +  #13#10 +
            'SELECT ' +                                                     #13#10 +
            '  relation_name, ' +                                           #13#10 +
            '  ref_relation_name, ' +                                       #13#10 +
            '  constraint_name, ' +                                         #13#10 +
            '  list_fields, list_ref_fields, update_rule, delete_rule ' +   #13#10 +
            'FROM  ' +                                                      #13#10 +
            '  dbs_fk_constraints  ' +                                      #13#10 +
            'WHERE  ' +                                                     #13#10 +
            '  relation_name = :RN ' +                                      #13#10 +
            '  AND list_fields = :FN ';
          q3.ParamByName('RN').AsString := FIgnoreTbls.Names[I];
          q3.ParamByName('FN').AsString := FieldsList[J];

          ExecSqlLogEvent(q3, 'PrepareRebindInvCards');
        end;
      end;

      Tr.Commit;

      LogEvent('[test] PrepareRebindInvCards... OK');
    finally
      q3.Free;
      q4.Free;
      qInsertGdDoc.Free;
      qInsertInvCard.Free;
      qInsertInvMovement.Free;
      qInsertTmpRebind.Free;
      Tr.Free;
      CardFeaturesList.Free;
      PkFieldsList.Free;
      FieldsList.Free;
    end;
  end;  
end;

procedure TgsDBSqueeze.RebindInvCards;
const
  CardkeyFieldCount = 2;
  CardkeyFieldNames: array[0..CardkeyFieldCount - 1] of String = ('FROMCARDKEY', 'TOCARDKEY');
var
  I: Integer;
  Tr: TIBTransaction;
  q3, q4: TIBSQL;
  qUpdateCard: TIBSQL;
  qUpdateFirstDocKey: TIBSQL;
  qUpdateInvMovement: TIBSQL;
begin
  if FDoRebindCards  then
  begin

    LogEvent('Rebinding cards...');

    Tr := TIBTransaction.Create(nil);
    q3 := TIBSQL.Create(nil);
    q4 := TIBSQL.Create(nil);
    qUpdateCard := TIBSQL.Create(nil);
    qUpdateFirstDocKey := TIBSQL.Create(nil);
    qUpdateInvMovement := TIBSQL.Create(nil);
    try

      SetBlockTriggerActive(False);     /// + ���������� ��������� INV_MOVEMENT

      Tr.DefaultDatabase := FIBDatabase;
      Tr.StartTransaction;

      q3.Transaction := Tr;
      q4.Transaction := Tr;
      qUpdateCard.Transaction := Tr;
      qUpdateFirstDocKey.Transaction := Tr;
      qUpdateInvMovement.Transaction := Tr;

      // ��������� ������ �� ������������ ��������
      qUpdateCard.SQL.Text :=
        'UPDATE ' +                                       #13#10 +
        '  inv_card c ' +                                 #13#10 +
        'SET ' +                                          #13#10 +
        '  c.parent = :NewParent ' +                      #13#10 +
        'WHERE ' +                                        #13#10 +
        '  c.parent = :OldParent ' +                      #13#10 +
        '  AND (' +                                       #13#10 +
        '    SELECT FIRST(1) m.movementdate ' +           #13#10 +
        '    FROM inv_movement m ' +                      #13#10 +
        '    WHERE m.cardkey = c.id ' +                   #13#10 +
        '    ORDER BY m.movementdate DESC' +              #13#10 +
        '  ) >= :CloseDate ';
      qUpdateCard.ParamByName('CloseDate').AsDateTime := FClosingDate;
      qUpdateCard.Prepare;

      // o�������� ������ �� �������� ������� � ���� �������
      qUpdateFirstDocKey.SQL.Text :=
        'UPDATE inv_card c ' +                            #13#10 +
        '   SET c.firstdocumentkey = :NewDockey ' +       #13#10 +
    //    '  c.firstdate = :NewDate ' +                             {TODO: ������}
        ' WHERE c.firstdocumentkey = :OldDockey ';
      qUpdateFirstDocKey.Prepare;

      // ��������� � �������� ������ �� ��������� ��������
      qUpdateInvMovement.SQL.Text :=
        'UPDATE ' +                                       #13#10 +
        '  inv_movement m ' +                             #13#10 +
        'SET ' +                                          #13#10 +
        '  m.cardkey = :NewCardkey ' +                    #13#10 +
        'WHERE ' +                                        #13#10 +
        '  m.cardkey = :OldCardkey ' +                    #13#10 +
        '  AND m.movementdate >= :CloseDate ';
      qUpdateInvMovement.ParamByName('CloseDate').AsDateTime := FClosingDate;
      qUpdateInvMovement.Prepare;


      q3.SQL.Text :=
        'SELECT ' +                                       #13#10 +
        '  CUR_CARDKEY       AS CurrentCardKey, ' +       #13#10 +
        '  NEW_CARDKEY       AS NewCardKey, ' +           #13#10 +
        '  CUR_FIRST_DOCKEY  AS CurrentFirstDocKey, ' +   #13#10 +
        '  FIRST_DOCKEY      AS FirstDocumentKey, ' +     #13#10 +
        '  FIRST_DATE        AS FirstDate, ' +            #13#10 +
        '  CUR_RELATION_NAME AS CurrentRelationName ' +   #13#10 +
        'FROM ' +                                         #13#10 +
        '  dbs_tmp_rebind_inv_cards ';
      ExecSqlLogEvent(q3, 'RebindInvCards');

      while not q3.EOF do
      begin
        if q3.FieldByName('NewCardKey').AsInteger > 0 then
        begin
          // ���������� ������ �� �������� ������� � ���� �������
          if q3.FieldByName('FirstDocumentKey').AsInteger > -1 then
          begin
            qUpdateFirstDocKey.ParamByName('OldDockey').AsInteger := q3.FieldByName('CurrentFirstDocKey').AsInteger;
            qUpdateFirstDocKey.ParamByName('NewDockey').AsInteger := q3.FieldByName('FirstDocumentKey').AsInteger;
            ///qUpdateFirstDocKey.ParamByName('NewDate').AsDateTime := q3.FieldByName('FirstDate').AsDateTime;

            ExecSqlLogEvent(qUpdateFirstDocKey, 'RebindInvCards');
            qUpdateFirstDocKey.Close;
          end;

          // ���������� ������ �� ������������ ��������
          qUpdateCard.ParamByName('OldParent').AsInteger :=  q3.FieldByName('CurrentCardKey').AsInteger;
          qUpdateCard.ParamByName('NewParent').AsInteger := q3.FieldByName('NewCardKey').AsInteger;

          ExecSqlLogEvent(qUpdateCard, 'RebindInvCards');
          qUpdateCard.Close;

          // ���������� ������ �� �������� �� ��������
          qUpdateInvMovement.ParamByName('OldCardkey').AsInteger := q3.FieldByName('CurrentCardKey').AsInteger;
          qUpdateInvMovement.ParamByName('NewCardkey').AsInteger := q3.FieldByName('NewCardKey').AsInteger;
        
          ExecSqlLogEvent(qUpdateInvMovement, 'RebindInvCards');
          qUpdateInvMovement.Close;                                               ////TODO: Exception: movement was made incorrect

          // ���������� � ��������������� �������� ��������� ���������� ������ �� ��������� ��������
          for I := 0 to CardkeyFieldCount - 1 do
          begin
            q4.SQL.Text :=
              'SELECT ' +                                 #13#10 +
              '  RDB$FIELD_NAME ' +                       #13#10 +
              'FROM ' +                                   #13#10 +
              '  RDB$RELATION_FIELDS ' +                  #13#10 +
              'WHERE ' +                                  #13#10 +
              '  RDB$RELATION_NAME = :RelationName ' +    #13#10 +
              '  AND RDB$FIELD_NAME = :FieldName';
            q4.ParamByName('RelationName').AsString := q3.FieldByName('CurrentRelationName').AsString;
            q4.ParamByName('FieldName').AsString := CardkeyFieldNames[I];
        
            ExecSqlLogEvent(q4, 'RebindInvCards');

            if not q4.RecordCount > 0 then //���� ��� ������� �������� ���� TOCARDKEY/FROMCARDKEY, �� ������� �� ������ ������ ����������
            begin
              q4.Close;
              q4.SQL.Text := Format(
                'UPDATE ' +                               #13#10 +
                '  %0:s line ' +                          #13#10 +
                'SET ' +                                  #13#10 +
                '  line.%1:s = :NewCardkey ' +            #13#10 +
                'WHERE ' +                                #13#10 +
                '  line.%1:s = :OldCardkey ' +            #13#10 +
                '  AND ( '+                               #13#10 +
                '    SELECT doc.documentdate ' +          #13#10 +
                '    FROM gd_document doc ' +             #13#10 +
                '    WHERE doc.id = line.documentkey ' +  #13#10 +
                '  ) >= :ClosingDate ',
                [q3.FieldByName('CurrentRelationName').AsString, CardkeyFieldNames[I]]);

              q4.ParamByName('OldCardkey').AsInteger := q3.FieldByName('CurrentCardKey').AsInteger;
              q4.ParamByName('NewCardkey').AsInteger := q3.FieldByName('NewCardKey').AsInteger;
              q4.ParamByName('ClosingDate').AsDateTime := FClosingDate;
            
              ExecSqlLogEvent(q4, 'RebindInvCards');
            end;
            q4.Close;
          end;
        end
        else begin
          LogEvent('[WARNING] Card will not be rebinded! cardkey=' + q3.FieldByName('CurrentCardKey').AsString);
        end;
        q3.Next;
      end;
      Tr.Commit;

      SetBlockTriggerActive(True);

      Tr.StartTransaction;
      q3.Close;

  /////////////////////////////////////////////////////////////////
      q3.SQL.Text :=
        'EXECUTE BLOCK ' +                                                                        #13#10 +
        '  RETURNS(S VARCHAR(16384)) ' +                                                          #13#10 +
        'AS ' +                                                                                   #13#10 +
        'BEGIN ' +                                                                                #13#10 +
        '  FOR ' +                                                                                #13#10 +
        '    SELECT ''ALTER TABLE '' || relation_name || '' ADD CONSTRAINT '' || ' +              #13#10 +
        '      constraint_name || '' FOREIGN KEY ('' || list_fields || '') REFERENCES '' || ' +   #13#10 +
        '      ref_relation_name || ''('' || list_ref_fields || '') '' || ' +                     #13#10 +
        '      IIF(update_rule = ''RESTRICT'', '''', '' ON UPDATE '' || update_rule) || ' +       #13#10 +
        '      IIF(delete_rule = ''RESTRICT'', '''', '' ON DELETE '' || delete_rule) ' +          #13#10 +
        '    FROM dbs_tmp_fk_constraints ' +                                                      #13#10 +
        '    INTO :S ' +                                                                          #13#10 +
        '  DO BEGIN ' +                                                                           #13#10 +
        '    SUSPEND; ' +                                                                         #13#10 +
        '    EXECUTE STATEMENT :S WITH AUTONOMOUS TRANSACTION; ' +                                #13#10 +
        '  END ' +                                                                                #13#10 +
        'END';
      ExecSqlLogEvent(q3, 'RebindInvCards');

      Tr.Commit;
      Tr.StartTransaction;
    
      LogEvent('Rebinding cards... OK');
    finally
      q3.Free;
      q4.Free;
      qUpdateInvMovement.Free;
      qUpdateFirstDocKey.Free;
      qUpdateCard.Free;
      Tr.Free;
    end;
  end;  
end;

function TgsDBSqueeze.CreateHIS(AnIndex: Integer): Integer;
var
  Tr: TIBTransaction;
  q: TIBSQL;
begin
  Assert(Connected);
  Result := 0;

  Tr := TIBTransaction.Create(nil);	
  q := TIBSQL.Create(nil);
  try
    Tr.DefaultDatabase := FIBDatabase;
    Tr.StartTransaction;
    q.Transaction := Tr;

    q.SQL.Text := Format(
      'SELECT g_his_create(%d, 0) FROM rdb$database', [AnIndex]);
    ExecSqlLogEvent(q, 'CreateHIS');

    Result :=  q.Fields[0].AsInteger;
    q.Close;

    Tr.Commit;
 
    if Result = 1 then
      LogEvent(Format('HIS[%d] ������ �������.', [AnIndex]))
    else begin
      LogEvent(Format('������� �������� HIS[%d] ����������� ��������!', [AnIndex]));       ///TODO: exception
    end;         
  finally
    q.Free;
    Tr.Free;  
  end;
end;

function TgsDBSqueeze.GetCountHIS(AnIndex: Integer): Integer;
var
  Tr: TIBTransaction;
  q: TIBSQL;
begin
  Assert(Connected);
  Result := -1;

  Tr := TIBTransaction.Create(nil);
  q := TIBSQL.Create(nil);
  try
    Tr.DefaultDatabase := FIBDatabase;
    Tr.StartTransaction;
    q.Transaction := Tr;

    q.SQL.Text := Format(
      'SELECT g_his_count(%d) FROM rdb$database', [AnIndex]);
    ExecSqlLogEvent(q, 'GetCountHIS');

    Result := q.Fields[0].AsInteger;
    q.Close;

    Tr.Commit;
  finally
    q.Free;
    Tr.Free;
  end;
end;

function TgsDBSqueeze.DestroyHIS(AnIndex: Integer): Integer;
var
  Tr: TIBTransaction;
  q: TIBSQL;
begin
  Assert(Connected);
  Result := 0;

  Tr := TIBTransaction.Create(nil);
  q := TIBSQL.Create(nil);
  try
    Tr.DefaultDatabase := FIBDatabase;
    Tr.StartTransaction;
    q.Transaction := Tr;

    q.SQL.Text := Format(
      'SELECT g_his_destroy(%d) FROM rdb$database', [AnIndex]);
    ExecSqlLogEvent(q, 'DestroyHIS');

    Result :=  q.Fields[0].AsInteger;
    q.Close;

    Tr.Commit;

    if Result = 1 then
      LogEvent(Format('HIS[%d] �������� �������.', [AnIndex]))
    else begin
      LogEvent(Format('������� ���������� HIS[%d] ����������� ��������!', [AnIndex]));
                                                                                ///TODO: exception
    end;
  finally
    q.Free;
    Tr.Free;
  end;
end;

procedure TgsDBSqueeze.CreateHIS_IncludeInHIS;
var
  Tr: TIBTransaction;
  q: TIBSQL;
  Kolvo: Integer;
  I: Integer;

  procedure IncludeCascadingSequences(const ATableName: String);
  const
    STEP_COUNT = 8;
  var
    LineDocTbls: TStringList;
    CrossLineTbls: TStringList;
    LineSetTbls: TStringList;
    ReProcTbl: String;
    EndReprocLineTbl: String;
    ReProcLineTbls: TStringList;
    GoLineReproc: Boolean;
    WaitReProc: Boolean;
    RefRelation: String;
    TmpStr: String;
    Step: Integer;
    ReprocIncrement: Integer;
    ReprocSituation: Boolean;
    ReprocCondition: Boolean;

    Tr, Tr2: TIBTransaction;
    q2: TIBQuery;
    q, q3, q4, q5: TIBSQL;
    FkFieldsList: TStringList;
    FkFieldsList2, FkFieldsList3: TStringList;
    FkFieldsListLine: TStringList;
    IsLine: Boolean;
    TblsNamesList: TStringList; // Process Queue
    AllProcessedTblsNames: TStringList;
    ExcFKTbls: TStringList;
    ReProc, ReProcAll: TStringList;
    GoReprocess, ReprocStarted: Boolean;
    EndReprocTbl: String;
    AllProc: TStringList;
    ProcTblsNamesList: TStringList;
    CascadeProcTbls: TStringList;
    I, J, K, N, IndexEnd, Inx, Counter, Kolvo, RealKolvo, RealKolvo2, ExcKolvo: Integer;
    IsAppended, IsDuplicate, DoNothing, GoToFirst, GoToLast, IsFirstIteration, Condition: Boolean;
    
    TmpList: TStringList;
    MainDuplicateTblName: String;
    LineTblsNames: String;
    LineTblsList:  TStringList;
    LinePosList: TStringList;
    LinePosInx: Integer;
    Line1PosInx, Line2PosInx: Integer;
    SelfFkFieldsListLine: TStringList;
    SelfFkFieldsList2: TStringList;

    function equalsIgnoreOrder(AList1: TStringList; AList2: TStringList): Boolean;
    begin
      Result := False;

      AList1.Sort;
      AList2.Sort;

      Result := (AList1.CommaText = AList2.CommaText);
    end;

  begin
    LogEvent('Including cascading sequences in HIS...');
    Assert(Trim(ATableName) <> '');
    try
      LineDocTbls := TStringList.Create;
      CrossLineTbls := TStringList.Create;
      LineSetTbls := TStringList.Create;
      ProcTblsNamesList := TStringList.Create;
      ReProcLineTbls := TStringList.Create;

      FkFieldsList := TStringList.Create;
      FkFieldsList2 := TStringList.Create;
      FkFieldsList3 := TStringList.Create;
      FkFieldsListLine := TStringList.Create;
      TblsNamesList := TStringList.Create;
      AllProcessedTblsNames := TStringList.Create;

      ReProc :=  TStringList.Create;
      ReProcAll :=  TStringList.Create;
      CascadeProcTbls := TStringList.Create;
      LineTblsList := TStringList.Create;
      AllProc := TStringList.Create;
      LinePosList := TStringList.Create;
      TmpList := TStringList.Create;
      ExcFKTbls := TStringList.Create;

      SelfFkFieldsListLine := TStringList.Create;
      SelfFkFieldsList2 := TStringList.Create;

      q := TIBSQL.Create(nil);
      q2 := TIBQuery.Create(nil);
      q3 := TIBSQL.Create(nil);
      q4 := TIBSQL.Create(nil);
      q5 := TIBSQL.Create(nil);

      Tr := TIBTransaction.Create(nil);
      Tr2 := TIBTransaction.Create(nil);
      try
        Tr.DefaultDatabase := FIBDatabase;
        Tr.StartTransaction;
        Tr2.DefaultDatabase := FIBDatabase;
        Tr2.StartTransaction;
        q.Transaction := Tr;
        q2.Transaction := Tr;
        q4.Transaction := Tr;
        q3.Transaction := Tr2;
        q5.Transaction := Tr2;

        LogEvent('[test] FIgnoreTbls: ' + FIgnoreTbls.Text);

        //include HIS_1 - ������� ��������

        //1) ������ ����. ������������ ������ ����� � ����������

        LineDocTbls.Append('GD_DOCUMENT=PARENT'); // �������
        LineDocTbls.Append('AC_ENTRY=DOCUMENTKEY||MASTERDOCKEY');
        LineDocTbls.Append('AC_RECORD=DOCUMENTKEY||MASTERDOCKEY');

          // ���� PK=FK             ������� �� ������ 1-to-1 � GD_DOCUMENT

        q.SQL.Text :=
          'SELECT ' +                                             #13#10 +
          '  TRIM(fc.relation_name)       AS relation_name, ' +   #13#10 +
          '  LIST(TRIM(fc.list_fields))   AS pkfk_field ' +       #13#10 +
          'FROM dbs_fk_constraints fc ' +                         #13#10 +
          '  JOIN DBS_SUITABLE_TABLES pc ' +                      #13#10 +
          '    ON pc.relation_name = fc.relation_name ' +         #13#10 +
          '      AND fc.list_fields = pc.list_fields ' +          #13#10 +
          'WHERE ' +                                              #13#10 +
          '  fc.ref_relation_name = ''GD_DOCUMENT'' ' +                                                                     #13#10 +
          '  AND fc.relation_name NOT IN (''GD_DOCUMENT'', ''AC_ENTRY'', ''AC_RECORD'', ''INV_CARD'', ''INV_MOVEMENT'') ' + #13#10 +
          '  AND fc.list_fields NOT LIKE ''%,%'' ' +                                                                        #13#10 +
          'GROUP BY fc.relation_name ';

        ExecSqlLogEvent(q, 'IncludeCascadingSequences');

        while not q.EOF do
        begin
          FkFieldsList.Clear;
          FkFieldsList.Text := StringReplace(q.FieldByName('pkfk_field').AsString, ',', #13#10, [rfReplaceAll, rfIgnoreCase]); // ���� PK=FK

          for I:=0 to FkFieldsList.Count-1 do
          begin
            if LineDocTbls.IndexOfName(UpperCase(q.FieldByName('relation_name').AsString)) <> -1 then
            begin
              if AnsiPos(Trim(FkFieldsList[I]), LineDocTbls.Values[UpperCase(q.FieldByName('relation_name').AsString)]) = 0 then
                LineDocTbls.Values[UpperCase(q.FieldByName('relation_name').AsString)] := LineDocTbls.Values[UpperCase(q.FieldByName('relation_name').AsString)] + '||' + Trim(FkFieldsList[I]);
            end
            else
              LineDocTbls.Append(UpperCase(q.FieldByName('relation_name').AsString) + '=' + Trim(FkFieldsList[I]));
          end;

          q.Next;
        end;
        q.Close;

        LineDocTbls.Append('INV_CARD=DOCUMENTKEY||FIRSTDOCUMENTKEY');

        // ����������� ����� �������� ��������� �������������: Line2 ����������� �� Line1 ������ ������ ����� Line1
        TmpList.CommaText := LineDocTbls.CommaText;
        for J:=0 to TmpList.Count-1 do
        begin
          Line2PosInx := LineDocTbls.IndexOfName(TmpList.Names[J]);
          Inx := Line2PosInx;

          q2.SQL.Text :=
            'SELECT ' +                                           #13#10 +
            '  TRIM(fc.ref_relation_name) AS ref_relation_name ' +#13#10 +
            'FROM dbs_fk_constraints fc ' +                       #13#10 +
            'WHERE  ' +                                           #13#10 +
            '  fc.relation_name = :rln ' +                        #13#10 +
            '  AND fc.list_fields NOT LIKE ''%,%'' ';

          q2.ParamByName('rln').AsString := TmpList.Names[J];
          ExecSqlLogEvent(q2, 'IncludeCascadingSequences');

          while not q2.EOF do
          begin
            if UpperCase(q2.FieldByName('ref_relation_name').AsString) <> 'GD_DOCUMENT' then
            begin
              Line1PosInx := LineDocTbls.IndexOfName(UpperCase(q2.FieldByName('ref_relation_name').AsString));
              if (Line1PosInx <> -1) and (Line1PosInx < Line2PosInx) then
              begin
                if Line1PosInx < Inx then
                  Inx := Line1PosInx;
              end;
            end;
            q2.Next;
          end;
          q2.Close;

          if Inx < Line2PosInx then
          begin
            LineDocTbls.Delete(Line2PosInx);
            LineDocTbls.Insert(Inx, TmpList.Names[J] + '=' + TmpList.Values[TmpList.Names[J]]);
          end;
        end;
        TmpList.Clear;

        LineDocTbls.Append('INV_MOVEMENT=DOCUMENTKEY');

        // 2) cross-���� ��� �������� Line
        for J:=0 to LineDocTbls.Count-1 do
        begin
          q.SQL.Text :=
            'SELECT DISTINCT ' +                                  #13#10 +
            '  TRIM(rf.crosstable) AS cross_relation_name, ' +    #13#10 +
            '  TRIM(fc.list_fields) AS cross_main_field ' +       #13#10 +
            'FROM AT_RELATION_FIELDS rf ' +                       #13#10 +
            '  JOIN dbs_fk_constraints fc ' +                     #13#10 +
            '    ON fc.relation_name = rf.crosstable ' +          #13#10 +
            '      AND fc.ref_relation_name = rf.relationname ' + #13#10 +
            'WHERE ' +                                            #13#10 +
            '  rf.relationname = :rln ' +                         #13#10 +
            '  AND  rf.crosstable IS NOT NULL ';

          q.ParamByName('rln').AsString := LineDocTbls.Names[J];
          ExecSqlLogEvent(q, 'IncludeCascadingSequences');

          if not q.EOF then
            TmpStr := LineDocTbls.Names[J] + '=';

          while not q.EOF do
          begin
            if CrossLineTbls.IndexOfName(UpperCase(q.FieldByName('cross_relation_name').AsString)) = -1 then
              CrossLineTbls.Append(UpperCase(q.FieldByName('cross_relation_name').AsString) + '=' + UpperCase(q.FieldByName('cross_main_field').AsString));

            TmpStr := TmpStr + UpperCase(q.FieldByName('cross_relation_name').AsString);         ///TODO �������� �������� ������������

            q.Next;

            if not q.EOF then
              TmpStr := TmpStr + ','
            else
             LineSetTbls.Append(TmpStr);
          end;

          q.Close;
          TmpStr := '';
        end;

        LogEvent('LineSetTbls: ' + LineSetTbls.Text);
        LogEvent('CrossLineTbls: ' + CrossLineTbls.Text);
        LogEvent('LineDocTbls: ' + LineDocTbls.Text);
                                                                                                     
        // 3) include HIS ���� �� ������� ���� ������ (�� �� ������� Line, �� �� crossLine)
        q2.SQL.Text :=
          'SELECT ' +                                             #13#10 +
          '  TRIM(fc.relation_name)       AS relation_name, ' +   #13#10 +
          '  LIST(TRIM(fc.list_fields))   AS fk_fields ' +        #13#10 +
          'FROM dbs_fk_constraints fc ' +                         #13#10 +
          '  LEFT JOIN AT_RELATION_FIELDS rf ' +                  #13#10 +
          '    ON rf.relationname = fc.ref_relation_name ' +      #13#10 +
          '      AND rf.crosstable = fc.relation_name ' +         #13#10 +
          'WHERE ' +                                              #13#10 +
          '  fc.ref_relation_name = ''GD_DOCUMENT'' ' +           #13#10 +
          '  AND rf.relationname IS NULL ' +                      #13#10 +
          '  AND fc.list_fields NOT LIKE ''%,%'' ' +              #13#10 +
          'GROUP BY fc.relation_name ';

        ExecSqlLogEvent(q2, 'IncludeCascadingSequences');

        while not q2.EOF do
        begin
          if (LineDocTbls.IndexOfName(UpperCase(q2.FieldByName('relation_name').AsString)) = -1) and
             (CrossLineTbls.IndexOfName(UpperCase(q2.FieldByName('relation_name').AsString)) = -1) then
          begin
            FkFieldsList2.Clear;
            FkFieldsList2.Text := StringReplace(q2.FieldByName('fk_fields').AsString, ',', #13#10, [rfReplaceAll, rfIgnoreCase]);

            for I:=0 to FkFieldsList2.Count-1 do                                                                 ////TODO ��� FK � ���� ������
            begin
              q3.SQL.Text :=
                'SELECT ' +
                '  SUM(g_his_include(1, rln.' +  FkFieldsList2[I] + ')) ' +           #13#10 +
                'FROM '  +                                                            #13#10 +
                   q2.FieldByName('relation_name').AsString + ' rln ' +               #13#10 +
                '  JOIN GD_DOCUMENT doc ON doc.id = rln.' + FkFieldsList2[I] + ' ' +  #13#10 +
                'WHERE ' +
                '  doc.parent IS NULL ';
              ExecSqlLogEvent(q3, 'IncludeCascadingSequences');
              q3.Close;
            end;
          end;

          q2.Next;
        end;
        q2.Close;
        ProgressMsgEvent('', 100);

        // 4) include linefield Line ���� �� ��� ���� ������ (�� �� ������� Line � �� �� cross-������ Line)
        for J:=0 to LineDocTbls.Count-1 do
        begin
          // line values
          FkFieldsList.Clear;
          FkFieldsList.Text := StringReplace(LineDocTbls.Values[LineDocTbls.Names[J]], '||', #13#10, [rfReplaceAll, rfIgnoreCase]);

          q2.SQL.Text :=
            'SELECT ' +                                           #13#10 +
            '  TRIM(fc.relation_name)     AS relation_name, ' +   #13#10 +
            '  LIST(TRIM(fc.list_fields)) AS fk_fields, ' +       #13#10 +
            '  TRIM(fc.list_ref_fields)   AS list_ref_fields, ' + #13#10 +
            '  TRIM(pc.list_fields)       AS pk_fields ' +        #13#10 +
            'FROM dbs_fk_constraints fc ' +                       #13#10 +
            '  LEFT JOIN DBS_SUITABLE_TABLES pc ' +               #13#10 +
            '    ON pc.relation_name = fc.relation_name ' +       #13#10 +
            '  LEFT JOIN AT_RELATION_FIELDS rf ' +                #13#10 +
            '    ON rf.relationname = fc.ref_relation_name ' +    #13#10 +
            '      AND rf.crosstable = fc.relation_name ' +       #13#10 +
            'WHERE ' +                                            #13#10 +
            '  fc.ref_relation_name = :rln ' +                    #13#10 +
            '  AND rf.relationname IS NULL ' +                    #13#10 +
            '  AND fc.list_fields NOT LIKE ''%,%'' ' +            #13#10 +
            'GROUP BY fc.relation_name, fc.list_ref_fields, pc.list_fields';

          q2.ParamByName('rln').AsString := LineDocTbls.Names[J];
          ExecSqlLogEvent(q2, 'IncludeCascadingSequences');

          while not q2.EOF do
          begin
            if (LineDocTbls.IndexOfName(UpperCase(q2.FieldByName('relation_name').AsString)) = -1) and
               (CrossLineTbls.IndexOfName(UpperCase(q2.FieldByName('relation_name').AsString)) = -1) then
            begin
              FkFieldsList2.Clear;
              FkFieldsList2.Text := StringReplace(q2.FieldByName('fk_fields').AsString, ',', #13#10, [rfReplaceAll, rfIgnoreCase]);

              if FkFieldsList2.Count > 0 then
              begin
                q3.SQL.Text :=
                  'SELECT ';
                for I:=0 to FkFieldsList2.Count-1 do
                begin
                  if I<>0 then
                    q3.SQL.Add(' , ');
                 { if LineDocTbls.Names[J] = 'INV_CARD' then
                  begin
                    if (FIgnoreTbls.IndexOfName(UpperCase( q2.FieldByName('relation_name').AsString )) <> -1) and
                      (AnsiPos(UpperCase( FkFieldsList2[I] ), FIgnoreTbls.Values[UpperCase( q2.FieldByName('relation_name').AsString )]) <> 0) then
                    begin
                      if not q2.FieldByName('pk_fields').IsNull then
                      begin
                        if AnsiPos(',', q2.FieldByName('pk_fields').AsString) = 0 then 
                          TmpStr := ' ' +
                            'g_his_has(0, rln.' + q2.FieldByName('pk_fields').AsString + ')=0 '
                        else
                          TmpStr := ' ' +
                            'g_his_has(0, rln.' + StringReplace(q2.FieldByName('pk_fields').AsString, ',', ')=0 AND g_his_has(0, rln.',[rfReplaceAll, rfIgnoreCase]) + ')=0 ';
                      end;      
                    end;  
                  end;}

                  if LineDocTbls.Names[J] = 'GD_DOCUMENT' then
                  begin
                    if TmpStr <> '' then
                    begin
                      q3.SQL.Add('  ' +
                        'SUM(IIF(' + TmpStr + ', g_his_include(1, rln.' + FkFieldsList2[I] + '), 0)) , ');
                    end
                    else
                      q3.SQL.Add('  ' +
                        'SUM(g_his_include(1, rln.' +  FkFieldsList2[I] + '))  , ');
                  end;

                  for K :=0 to FkFieldsList.Count-1 do
                  begin
                    if K<>0 then
                      q3.SQL.Add(', ');

                    if TmpStr <> '' then
                    begin
                      q3.SQL.Add('  ' +
                        'SUM(IIF(' + TmpStr + ', g_his_include(1, line' + IntToStr(I) + '.' + FkFieldsList[K] + ') ');

                      if LineDocTbls.Names[J] = 'INV_CARD' then
                        q3.SQL.Add(' + g_his_include(2, line' + IntToStr(I) + '.id) ');

                      q3.SQL.Add(', 0)) ')
                    end
                    else begin
                      q3.SQL.Add('  ' +
                        'SUM(g_his_include(1, line' + IntToStr(I) + '.' + FkFieldsList[K] + ') ');

                      if LineDocTbls.Names[J] = 'INV_CARD' then
                        q3.SQL.Add(' + g_his_include(2, line' + IntToStr(I) + '.id) ');

                      q3.SQL.Add(') ');
                    end;    
                  end;

                  TmpStr := '';
                end;
                q3.SQL.Add(' ' +
                  'FROM '  +                                                    #13#10 +
                     q2.FieldByName('relation_name').AsString + ' rln ');
                for I:=0 to FkFieldsList2.Count-1 do
                begin
                  q3.SQL.Add('  ' +
                    'LEFT JOIN ' +                                              #13#10 +
                       LineDocTbls.Names[J] + ' line' + IntToStr(I) + ' ' +     #13#10 +
                    '    ON line' + IntToStr(I) + '.' + q2.FieldByName('list_ref_fields').AsString + ' = rln.' + FkFieldsList2[I]);
                end;

                ExecSqlLogEvent(q3, 'IncludeCascadingSequences');
                q3.Close;
              end;
            end;

            q2.Next;
          end;
          q2.Close;
        end;
        ProgressMsgEvent('', 100);                                              //TODO: � ��������
        
        // 5) ��� ���������� Line ������ �������� �� ����� ���� � �����-�������, ���� ����� ����-���������
        ReprocCondition := False;
        ReprocSituation := False;
        Step := 0;
        ReprocIncrement := (LineDocTbls.Count) div STEP_COUNT;
        IsFirstIteration := True;
        J := 0;
        while J < LineDocTbls.Count do
        begin
          if GoReprocess then
          begin
            GoReprocess := False;
            ReprocSituation := False;
            Step := 0;
            ProcTblsNamesList.Clear;
          end;
          ProcTblsNamesList.Append(LineDocTbls.Names[J]);
          ReprocCondition := False;

          RealKolvo := 0;
          ReProcTbl := '';
          // line values
          FkFieldsList.Clear;
          FkFieldsList.Text := StringReplace(LineDocTbls.Values[LineDocTbls.Names[J]], '||', #13#10, [rfReplaceAll, rfIgnoreCase]);

          //---------��������� FKs Line
          // 5.1) ��������� ������� Line ������� � HIS
            // ��� ���������� ������ �������� Line ������ �������� �� ����� ���� FK

          if IsFirstIteration then
          begin
            if LineDocTbls.Names[J] = 'GD_DOCUMENT' then
            begin
              q3.SQL.Text :=
                'SELECT SUM(g_his_include(1, id)) ' +           #13#10 +
                '  FROM gd_document ' +                         #13#10 +
                ' WHERE parent < 147000000';
              ExecSqlLogEvent(q3, 'IncludeCascadingSequences');
              q3.Close;
            end;

            // if PK<147000000 ������� ���� include HIS, ����� ����� �������� FKs ����� �������
            // PKs Line
            q4.SQL.Text :=
              'SELECT ' +                                     #13#10 +
              '  TRIM(c.list_fields) AS pk_fields ' +         #13#10 +
              'FROM ' +                                       #13#10 +
              '  dbs_pk_unique_constraints c ' +              #13#10 +
              'WHERE ' +                                      #13#10 +
              '  c.relation_name = :rln ' +                   #13#10 +
              '  AND c.constraint_type = ''PRIMARY KEY'' ';

            q4.ParamByName('rln').AsString := LineDocTbls.Names[J];
            ExecSqlLogEvent(q4, 'IncludeCascadingSequences');

            if not q4.EOF then
            begin
              FkFieldsList2.Clear;
              if AnsiPos(',', q4.FieldByName('pk_fields').AsString) = 0 then
                FkFieldsList2.Text := UpperCase(q4.FieldByName('pk_fields').AsString)
              else
                FkFieldsList2.Text := UpperCase(StringReplace(q4.FieldByName('pk_fields').AsString, ',', #13#10, [rfReplaceAll, rfIgnoreCase]));

              q3.SQL.Text :=
                'SELECT ';
              for I:=0 to FkFieldsList.Count-1 do
              begin
                if I <> 0 then
                  q3.SQL.Add(', ');

                q3.SQL.Add('  ' +
                  'SUM(g_his_include(1, rln.' + FkFieldsList[I] + ')) ');
              end;
              q3.SQL.Add(' ' +
                'FROM ' + LineDocTbls.Names[J] + ' rln ' +    #13#10 +
                'WHERE ');
              for I:=0 to FkFieldsList2.Count-1 do //PKs
              begin
                if I <> 0 then
                   q3.SQL.Add(' OR ');

                q3.SQL.Add('  ' +
                  'rln.' +  FkFieldsList2[I] + ' < 147000000 ');
              end;

              ExecSqlLogEvent(q3, 'IncludeCascadingSequences');
              for I:=0 to q3.Current.Count-1 do // = FkFieldsList.Count
              begin
                if q3.Fields[I].AsInteger > 0 then
                begin
                  RealKolvo := RealKolvo + q3.Fields[I].AsInteger;  // ������ ��� ������������� � gd_document
                  LogEvent('REPROCESS! LineTable: ' + LineDocTbls.Names[J] + ' FK: ' + FkFieldsList[I] + ' --> GD_DOCUMENT');
                end;
              end;
              q3.Close;
              FkFieldsList2.Clear;
            end;
            q4.Close;
          end;

          if LineDocTbls.Names[J] = 'GD_DOCUMENT' then
          begin
            repeat
              q3.Close;
              q3.SQL.Text :=
                'SELECT SUM(g_his_include(1, parent)) AS RealCount ' +          #13#10 +
                '  FROM gd_document ' +                                         #13#10 +
                ' WHERE g_his_has(1, id)=1 ';
              ExecSqlLogEvent(q3, 'CreateHIS_IncludeInHIS');
            until q3.FieldByName('RealCount').AsInteger = 0;
            q3.Close;
          end;

          // ��� FK ���� � Line
          q2.SQL.Text :=                                                        ///TODO: �������. Prepare
            'SELECT ' +                                                         #13#10 +
            '  TRIM(fc.list_fields)       AS fk_field, ' +                      #13#10 +
            '  TRIM(fc.ref_relation_name) AS ref_relation_name, ' +             #13#10 +
            '  TRIM(fc.list_ref_fields)   AS list_ref_fields ' +                #13#10 +
            'FROM dbs_fk_constraints fc ' +                                     #13#10 +
            'WHERE  ' +                                                         #13#10 +
            '  fc.relation_name = :rln ' +                                      #13#10 +
            '  AND fc.list_fields NOT LIKE ''%,%'' ';

          q2.ParamByName('rln').AsString := LineDocTbls.Names[J];
          ExecSqlLogEvent(q2, 'IncludeCascadingSequences');

          FkFieldsListLine.Clear;
          FkFieldsList2.Clear;
          SelfFkFieldsListLine.Clear;
          SelfFkFieldsList2.Clear;
          while not q2.EOF do
          begin
            if LineDocTbls.IndexOfName(UpperCase( q2.FieldByName('ref_relation_name').AsString )) <> -1 then
            begin
              if LineDocTbls.Names[J] <> UpperCase( q2.FieldByName('ref_relation_name').AsString ) then
              begin
                FkFieldsListLine.Append(UpperCase( q2.FieldByName('fk_field').AsString ) + '=' + UpperCase( q2.FieldByName('ref_relation_name').AsString ));
                FkFieldsList2.Append(UpperCase( q2.FieldByName('list_ref_fields').AsString ));
              end
              else begin// ������ �� ���� ���� - ���������� ��������, ����� �������� �������������
                SelfFkFieldsListLine.Append(UpperCase( q2.FieldByName('fk_field').AsString ) + '=' + UpperCase( q2.FieldByName('ref_relation_name').AsString ));
                SelfFkFieldsList2.Append(UpperCase( q2.FieldByName('list_ref_fields').AsString ));
              end;  
            end;

            q2.Next;
          end;
          q2.Close;

          
          {if FIgnoreTbls.IndexOfName(LineDocTbls.Names[J]) <> -1 then
          begin
            q2.SQL.Text := 
              'SELECT TRIM(list_fields) AS pk_fields ' +                        #13#10 +
              '  FROM DBS_SUITABLE_TABLES ' +                                   #13#10 +
              ' WHERE relation_name = :rln ';
            q2.ParamByName('rln').AsString := LineDocTbls.Names[J];
            ExecSqlLogEvent(q2, 'IncludeCascadingSequences');

            if not q2.FieldByName('pk_fields').IsNull then
            begin
              if AnsiPos(',', q2.FieldByName('pk_fields').AsString) = 0 then 
                TmpStr := ' ' +
                  'g_his_has(0, rln.' + q2.FieldByName('pk_fields').AsString + ')=0 '
              else
                TmpStr := ' ' +
                  'g_his_has(0, rln.' + StringReplace(q2.FieldByName('pk_fields').AsString, ',', ')=0 AND g_his_has(0, rln.',[rfReplaceAll, rfIgnoreCase]) + ')=0 ';
            end;
            q2.Close;
          end;  }
          if LineDocTbls.Names[J] = 'INV_CARD' then  // �� ������������ ������ ��� ������� ��� inv_movement - ����� �������
          begin
            {if TmpStr <> '' then
              TmpStr := TmpStr + ' AND ';}

            TmpStr := ' (g_his_has(2, rln.id)=1) OR (rln.id < 147000000) ' ;
          end;


          if FkFieldsList.Count = 1 then
          begin
            if FkFieldsListLine.IndexOfName(FkFieldsList[0]) <> -1 then
            begin
              FkFieldsList2.Delete(FkFieldsListLine.IndexOfName(FkFieldsList[0]));
              FkFieldsListLine.Delete(FkFieldsListLine.IndexOfName(FkFieldsList[0]));
            end
            else if SelfFkFieldsListLine.IndexOfName(FkFieldsList[0]) <> -1 then
            begin
              SelfFkFieldsList2.Delete(SelfFkFieldsListLine.IndexOfName(FkFieldsList[0]));
              SelfFkFieldsListLine.Delete(SelfFkFieldsListLine.IndexOfName(FkFieldsList[0]));
            end;
          end;

          if SelfFkFieldsListLine.Count <> 0 then
          begin
            repeat
              FkFieldsList3.Clear;

              q3.Close;
              q3.SQL.Text :=
                'SELECT ';
              for I:=0 to SelfFkFieldsListLine.Count-1 do
              begin
                RefRelation := SelfFkFieldsListLine.Values[SelfFkFieldsListLine.Names[I]];
                FkFieldsList3.Text := StringReplace(LineDocTbls.Values[RefRelation], '||', #13#10, [rfReplaceAll, rfIgnoreCase]); // ������� ���� ������� ref_relation_name
                N := FkFieldsList.IndexOf(SelfFkFieldsListLine.Names[I]);
                if I <> 0 then
                  q3.SQL.Add(' + ');

                q3.SQL.Add('  ' +
                  'SUM( ' +
                  '  IIF(( ');
                   
                {if (TmpStr <> '') and 
                  ((AnsiPos(UpperCase( SelfFkFieldsListLine.Names[I] ), FIgnoreTbls.Values[LineDocTbls.Names[J]]) <> 0)) then
                  q3.SQL.Add(' ' + 
                    TmpStr + ') AND (');}
                if LineDocTbls.Names[J] = 'INV_CARD' then
                  q3.SQL.Add(TmpStr)
                else begin  
                  if N = -1 then  // �� �������
                  begin
                    for K:=0 to FkFieldsList.Count-1 do
                    begin
                      if K <> 0 then
                        q3.SQL.Add('  OR ');

                      q3.SQL.Add('  ' +
                        '   (g_his_has(1, rln.' + FkFieldsList[K] + ') = 1 ');

                      if IsFirstIteration then
                        q3.SQL.Add(' OR rln.' + FkFieldsList[K] + ' < 147000000 ');

                      q3.SQL.Add('  ' +
                        ') ');
                    end;
                  end
                  else begin
                    TmpList.Clear;
                    TmpList.Text := FkFieldsList.Text;
                    TmpList.Delete(N);
                    for K:=0 to TmpList.Count-1 do
                    begin
                      if K <> 0 then
                        q3.SQL.Add('  OR ');
                      q3.SQL.Add('  ' +
                        '(g_his_has(1, rln.' + TmpList[K] + ') = 1 ');

                      if IsFirstIteration then
                        q3.SQL.Add(' OR rln.' + TmpList[K] + ' < 147000000 ');

                      q3.SQL.Add('  ' +
                        ') ');
                    end;
                  end;
                end;
                q3.SQL.Add('), ');

                if RefRelation = 'GD_DOCUMENT' then
                  q3.SQL.Add('  ' +
                    'g_his_include(1, rln.' +  SelfFkFieldsListLine.Names[I] + ') ')
                else begin
                  for K:=0 to FkFieldsList3.Count-1 do
                  begin
                   if K <> 0 then
                      q3.SQL.Add(' + ');

                    q3.SQL.Add('  ' +
                      'g_his_include(1, line' + IntToStr(I) + '.' +  FkFieldsList3[K] + ') ' );
                  end;

                  if RefRelation = 'INV_CARD' then // ���� ���� ������ �� �� �������
                    q3.SQL.Add(' + ' +
                      ' g_his_include(2, line' + IntToStr(I) + '.id)');
                end;

                q3.SQL.Add(', 0)) ');
              end;

              q3.SQL.Add(' AS RealCount ' +
                'FROM ' + LineDocTbls.Names[J] + ' rln ');

              for I:=0 to SelfFkFieldsListLine.Count-1 do
              begin
                if SelfFkFieldsListLine.Values[SelfFkFieldsListLine.Names[I]] <> 'GD_DOCUMENT' then
                  q3.SQL.Add('  ' +
                    'LEFT JOIN ' + SelfFkFieldsListLine.Values[SelfFkFieldsListLine.Names[I]] + ' line' + IntToStr(I) + #13#10 +
                    '  ON line' + IntToStr(I) + '.' + SelfFkFieldsList2[I] + ' = rln.' + SelfFkFieldsListLine.Names[I]);
              end;

              ExecSqlLogEvent(q3, 'IncludeCascadingSequences');
            
            until q3.FieldByName('RealCount').AsInteger = 0;
            
            q3.Close;
          end;

          //====================================


          if FkFieldsListLine.Count <> 0 then
          begin

            FkFieldsList3.Clear;

            q3.SQL.Text :=
              'SELECT ';
            for I:=0 to FkFieldsListLine.Count-1 do
            begin
              RefRelation := FkFieldsListLine.Values[FkFieldsListLine.Names[I]];
              FkFieldsList3.Text := StringReplace(LineDocTbls.Values[RefRelation], '||', #13#10, [rfReplaceAll, rfIgnoreCase]); // ������� ���� ������� ref_relation_name
              N := FkFieldsList.IndexOf(FkFieldsListLine.Names[I]);
              if I <> 0 then
                q3.SQL.Add(', ');

              q3.SQL.Add('  ' +
                'SUM( ' +
                '  IIF(( ');
                 
              {if (TmpStr <> '') and 
                ((AnsiPos(UpperCase( FkFieldsListLine.Names[I] ), FIgnoreTbls.Values[LineDocTbls.Names[J]]) <> 0)) then
                q3.SQL.Add(' ' + 
                  TmpStr + ') AND (');}
              if LineDocTbls.Names[J] = 'INV_CARD' then
                q3.SQL.Add(TmpStr)
              else begin  
                if N = -1 then  // �� �������
                begin
                  for K:=0 to FkFieldsList.Count-1 do
                  begin
                    if K <> 0 then
                      q3.SQL.Add('  OR ');

                    q3.SQL.Add('  ' +
                      '   (g_his_has(1, rln.' + FkFieldsList[K] + ') = 1 ');

                    if IsFirstIteration then
                      q3.SQL.Add(' OR rln.' + FkFieldsList[K] + ' < 147000000 ');

                    q3.SQL.Add('  ' +
                      ') ');
                  end;
                end
                else begin
                  TmpList.Clear;
                  TmpList.Text := FkFieldsList.Text;
                  TmpList.Delete(N);
                  for K:=0 to TmpList.Count-1 do
                  begin
                    if K <> 0 then
                      q3.SQL.Add('  OR ');
                    q3.SQL.Add('  ' +
                      '(g_his_has(1, rln.' + TmpList[K] + ') = 1 ');

                    if IsFirstIteration then
                      q3.SQL.Add(' OR rln.' + TmpList[K] + ' < 147000000 ');

                    q3.SQL.Add('  ' +
                      ') ');
                  end;
                end;
              end;
              q3.SQL.Add('), ');

              if RefRelation = 'GD_DOCUMENT' then
                q3.SQL.Add('  ' +
                  'g_his_include(1, rln.' +  FkFieldsListLine.Names[I] + ') ')
              else begin
                for K:=0 to FkFieldsList3.Count-1 do
                begin
                 if K <> 0 then
                    q3.SQL.Add(' + ');

                  q3.SQL.Add('  ' +
                    'g_his_include(1, line' + IntToStr(I) + '.' +  FkFieldsList3[K] + ') ' );
                end;

                if RefRelation = 'INV_CARD' then // ���� ���� ������ �� �� �������
                  q3.SQL.Add(' + ' +
                    ' g_his_include(2, line' + IntToStr(I) + '.id)');
              end;

              q3.SQL.Add(', 0)) ');
            end;


            q3.SQL.Add(' ' +
              'FROM ' + LineDocTbls.Names[J] + ' rln ');

            for I:=0 to FkFieldsListLine.Count-1 do
            begin
              if FkFieldsListLine.Values[FkFieldsListLine.Names[I]] <> 'GD_DOCUMENT' then
                q3.SQL.Add('  ' +
                  'LEFT JOIN ' + FkFieldsListLine.Values[FkFieldsListLine.Names[I]] + ' line' + IntToStr(I) + #13#10 +
                  '  ON line' + IntToStr(I) + '.' + FkFieldsList2[I] + ' = rln.' + FkFieldsListLine.Names[I]);
            end;

            ExecSqlLogEvent(q3, 'IncludeCascadingSequences');

            for I:=0 to q3.Current.Count-1 do // = FkFieldsListLine.Count
            begin
              if q3.Fields[I].AsInteger > 0 then
              begin
                RefRelation := FkFieldsListLine.Values[FkFieldsListLine.Names[I]];

                if ProcTblsNamesList.IndexOf(RefRelation) <> -1 then
                begin
                  RealKolvo := RealKolvo + q3.Fields[I].AsInteger;  // ������ ��� ������������� � gd_document
                  LogEvent('REPROCESS! LineTable: ' + LineDocTbls.Names[J] + ' FK: ' + FkFieldsListLine.Names[I] + ' --> ' + RefRelation);
                end;  
              end;
            end;
            q3.Close;
          end;
          TmpStr := '';


          // 5.2) if Line �������� ����-���������, �� ���������� �� CROSS-�������, ����� ��������� ����������� ������

          //---��������� PKs  ���� ���� ����� ����-���������

          if LineSetTbls.IndexOfName(LineDocTbls.Names[J]) <> -1 then
          begin
            if LineDocTbls.Names[J] <> 'INV_CARD' then /// inv_card.id ��� ��������� - HIS_2
            begin
              // PKs Line     (PK=FK ���������� ���)
              q4.SQL.Text :=
                'SELECT ' +                                     #13#10 +
                '  TRIM(c.list_fields) AS pk_fields ' +         #13#10 +
                'FROM ' +                                       #13#10 +
                '  dbs_pk_unique_constraints c ' +              #13#10 +
                'WHERE ' +                                      #13#10 +
                '  c.relation_name = :rln ' +                   #13#10 +
                '  AND c.constraint_type = ''PRIMARY KEY'' ' +  #13#10 +
                '  AND NOT EXISTS( ' +                          #13#10 +
                '    SELECT * ' +                               #13#10 +
                '    FROM dbs_fk_constraints fc ' +             #13#10 +
                '    WHERE ' +                                  #13#10 +
                '      fc.relation_name = c.relation_name ' +   #13#10 +
                '      AND fc.list_fields = c.list_fields) ';

              q4.ParamByName('rln').AsString := LineDocTbls.Names[J];
              ExecSqlLogEvent(q4, 'IncludeCascadingSequences');

              if not q4.EOF then
              begin
                FkFieldsList3.Clear;
                if AnsiPos(',', q4.FieldByName('pk_fields').AsString) = 0 then
                  FkFieldsList3.Text := UpperCase(q4.FieldByName('pk_fields').AsString)
                else
                  FkFieldsList3.Text := UpperCase(StringReplace(q4.FieldByName('pk_fields').AsString, ',', #13#10, [rfReplaceAll, rfIgnoreCase]));

                // include pk Line ���� ������� ���� � HIS

                q3.SQL.Text :=
                  'SELECT ';
                for I:=0 to FkFieldsList3.Count-1 do //pks
                begin
                  q3.SQL.Add(' ' +
                    ' SUM(g_his_include(1, rln.' +  FkFieldsList3[I] + ')) ');

                  if I < FkFieldsList3.Count-1 then
                    q3.SQL.Add(', ');
                end;
                q3.SQL.Add(' ' +
                  'FROM '  +
                     LineDocTbls.Names[J] + ' rln ' +           #13#10 +
                  'WHERE ');
                for I:=0 to FkFieldsList.Count-1 do //line values
                begin
                  if I <> 0 then
                     q3.SQL.Add(' OR ');

                  q3.SQL.Add('  ' +
                    '(g_his_has(1, rln.' +  FkFieldsList[I] + ') = 1) ');

                  if IsFirstIteration then
                    q3.SQL.Add(' OR (rln.' +  FkFieldsList[I] + ' < 147000000) ');
                end;

                ExecSqlLogEvent(q3, 'IncludeCascadingSequences');
                q3.Close;
              end;
              q4.Close;
            end;
            //---------��������� �����-�������� Line

            FkFieldsList3.Clear;
            if AnsiPos(',', LineSetTbls.Values[LineDocTbls.Names[J]]) = 0 then
              FkFieldsList3.Text := LineSetTbls.Values[LineDocTbls.Names[J]]
            else
              FkFieldsList3.Text := StringReplace(LineSetTbls.Values[LineDocTbls.Names[J]], ',', #13#10, [rfReplaceAll, rfIgnoreCase]);

            for N:=0 to FkFieldsList3.Count-1 do
            begin
              {if FIgnoreTbls.IndexOfName(FkFieldsList3[N]) <> -1 then
              begin
                q2.SQL.Text :=
                  'SELECT TRIM(list_fields) AS pk_fields ' +                       #13#10 +
                  '  FROM DBS_SUITABLE_TABLES ' +                                  #13#10 +
                  ' WHERE relation_name = :rln ';
                q2.ParamByName('rln').AsString := FkFieldsList3[N];
                ExecSqlLogEvent(q2, 'IncludeCascadingSequences');

                if not q2.FieldByName('pk_fields').IsNull then
                begin
                  if AnsiPos(',', q2.FieldByName('pk_fields').AsString) = 0 then 
                    TmpStr := ' ' +
                      'g_his_has(0, rln.' + q2.FieldByName('pk_fields').AsString + ')=0 '
                  else
                    TmpStr := ' ' +
                      'g_his_has(0, rln.' + StringReplace(q2.FieldByName('pk_fields').AsString, ',', ')=0 AND g_his_has(0, rln.',[rfReplaceAll, rfIgnoreCase]) + ')=0 ';
                end;  
                q2.Close;    
              end;}

              // ������� ��� �� ������� FK cascade ���� � �����-�������
              q4.SQL.Text :=                                                 ///TODO: �������. Prepare
                 'SELECT ' +                                                                          #13#10 +
                 '  TRIM(fc.list_fields)       AS list_field, ' +                                     #13#10 +
                 '  TRIM(fc.ref_relation_name) AS ref_relation_name, ' +                              #13#10 +
                  '  TRIM(fc.list_ref_fields)   AS list_ref_fields ' +                                #13#10 +
                 'FROM dbs_fk_constraints fc ' +                                                      #13#10 +
                 'WHERE  ' +                                                                          #13#10 +
                 '  fc.relation_name = :rln ' +                                                       #13#10 +
                 '  AND fc.list_fields <> ''' + CrossLineTbls.Values[FkFieldsList3[N]] + ''' ' +      #13#10 +
                 '  AND fc.list_fields NOT LIKE ''%,%'' ';
              q4.ParamByName('rln').AsString := FkFieldsList3[N];
              ExecSqlLogEvent(q4, 'IncludeCascadingSequences');

              FkFieldsListLine.Clear;
              FkFieldsList2.Clear;
              while not q4.EOF do
              begin
                if LineDocTbls.IndexOfName(UpperCase( q4.FieldByName('ref_relation_name').AsString )) <> -1 then
                begin
                  FkFieldsListLine.Append(UpperCase( q4.FieldByName('list_field').AsString ) + '=' + UpperCase( q4.FieldByName('ref_relation_name').AsString ));
                  FkFieldsList2.Append(UpperCase( q4.FieldByName('list_ref_fields').AsString ));
                end;

                q4.Next;
              end;
              q4.Close;

              if FkFieldsListLine.Count <> 0 then
              begin
                q3.SQL.Text :=
                  'SELECT ';
                for I:=0 to FkFieldsListLine.Count-1 do
                begin
                  RefRelation := FkFieldsListLine.Values[FkFieldsListLine.Names[I]];
                  FkFieldsList.Clear;
                  FkFieldsList.Text := StringReplace(LineDocTbls.Values[FkFieldsListLine.Values[FkFieldsListLine.Names[I]]], '||', #13#10, [rfReplaceAll, rfIgnoreCase]);   // ������� ���� ������� ref_relation_name

                  if I<>0 then
                    q3.SQL.Add(', ');
                  
                  q3.SQL.Add('  ' +
                      'SUM( ');
                  
                {  if (TmpStr <> '') and 
                    (AnsiPos(UpperCase( FkFieldsListLine.Names[I] ), FIgnoreTbls.Values[FkFieldsList3[N]]) <> 0) then
                    q3.SQL.Add(' IIF(' + TmpStr + ', ');}
                  
                   
                  if RefRelation = 'GD_DOCUMENT' then
                  begin
                    q3.SQL.Add(' IIF( g_his_has(1, rln.'+ CrossLineTbls.Values[FkFieldsList3[N]] + ') = 1 ');
                    if IsFirstIteration then
                      q3.SQL.Add('  ' +
                        '  OR rln.' + CrossLineTbls.Values[FkFieldsList3[N]] + ' < 147000000');
                      q3.SQL.Add(', ');

                    q3.SQL.Add('  ' +
                      'g_his_include(1, rln.' +  FkFieldsListLine.Names[I] + ')')
                  end  
                  else begin
                    if RefRelation = 'INV_CARD' then // ���� ���� ������ �� �� �������                                        
                    begin
                      q3.SQL.Add(' IIF( g_his_has(2, line' + IntToStr(I) + '.id)=1');
                      if IsFirstIteration then
                        q3.SQL.Add('  ' +
                          '  OR line.' +  IntToStr(I) + '.id < 147000000');
                      
                      q3.SQL.Add(', ' + 
                        'g_his_include(2, line' + IntToStr(I) + '.id) ');
                      for K:=0 to FkFieldsList.Count-1 do
                      begin
                       if K <> 0 then
                          q3.SQL.Add(' + ');

                        q3.SQL.Add('  ' +
                          'g_his_include(1, line' + IntToStr(I) + '.' +  FkFieldsList[K] + ') ' );
                      end;  
                    end
                    else begin
                      q3.SQL.Add(' IIF( g_his_has(1, rln.'+ CrossLineTbls.Values[FkFieldsList3[N]] + ') = 1 ');
                      if IsFirstIteration then
                        q3.SQL.Add('  ' +
                          '  OR rln.' + CrossLineTbls.Values[FkFieldsList3[N]] + ' < 147000000');
                      q3.SQL.Add(', ');

                      for K:=0 to FkFieldsList.Count-1 do
                      begin
                       if K <> 0 then
                          q3.SQL.Add(' + ');

                        q3.SQL.Add('  ' +
                          'g_his_include(1, line' + IntToStr(I) + '.' +  FkFieldsList[K] + ') ' );
                      end;
                    end;
                  end;
                  q3.SQL.Add(', 0)');

                 { if (TmpStr <> '') and
                    (AnsiPos(UpperCase( FkFieldsListLine.Names[I] ), FIgnoreTbls.Values[FkFieldsList3[N]]) <> 0) then
                    q3.SQL.Add(', 0)');}

                  q3.SQL.Add('  ' +
                    ')');
                end;

                q3.SQL.Add('  ' +
                  'FROM '  + FkFieldsList3[N] + ' rln ');
                for I:=0 to FkFieldsListLine.Count-1 do
                begin
                  if FkFieldsListLine.Values[FkFieldsListLine.Names[I]] <> 'GD_DOCUMENT' then
                    q3.SQL.Add('  ' +
                      'LEFT JOIN ' +                                                                                 #13#10 +
                         FkFieldsListLine.Values[FkFieldsListLine.Names[I]] + ' line' + IntToStr(I) + ' ' +          #13#10 +
                      '    ON line' + IntToStr(I) + '.' + FkFieldsList2[I] + ' = rln.' + FkFieldsListLine.Names[I]);
                end;

                ExecSqlLogEvent(q3, 'IncludeCascadingSequences');

                for I:=0 to q3.Current.Count-1 do // = FkFieldsListLine.Count
                begin

                  if q3.Fields[I].AsInteger > 0 then
                  begin
                    RefRelation := FkFieldsListLine.Values[FkFieldsListLine.Names[I]];
                    
                    if ProcTblsNamesList.IndexOf(RefRelation) <> -1 then
                    begin
                      RealKolvo := RealKolvo + q3.Fields[I].AsInteger;  // ������ ��� ������������� � gd_document
                      LogEvent('REPROCESS! CrossTable: ' + FkFieldsList3[N]  + ' FK: ' + FkFieldsListLine.Names[I] + ' --> ' + RefRelation);
                    end;  
                  end;
                end;
                q3.Close;
              end;
              TmpStr := '';
            end;
          end;


          LogEvent('==> ' + IntToStr(J) + ' ' + LineDocTbls.Names[J]);
////////////
          if RealKolvo > 0 then // �������������� � ����� ����
            ReprocSituation := True;
          
          if not IsFirstIteration then
          begin
            if Step <> STEP_COUNT-1 then
            begin
              if ((J+1) mod ReprocIncrement) = 0 then
              begin
                Inc(Step);
                ReprocCondition := True;
              end;  
            end
            else if J = LineDocTbls.Count-1 then
              ReprocCondition := True;
          end
          else if J = LineDocTbls.Count-1 then
          begin
            IsFirstIteration := False;
            ReprocCondition := True;
          end;

          // ������ �������������
          if  ReprocSituation and ReprocCondition then
          begin
            GoReprocess := True;
            J := 0 - 1;

            LogEvent('GO REPROCESS gd_doc!');
          end;
////////////
          ProgressMsgEvent('');
          Inc(J);
        end;

        // �������� ������������ ������� ����� ������ ��� ��� ��������� � �������
        FCascadeTbls.Text := LineDocTbls.Text;
        if CrossLineTbls.Count > 0 then
          FCascadeTbls.CommaText := FCascadeTbls.CommaText + ',' + CrossLineTbls.CommaText;

        Tr.Commit;
        Tr2.Commit;
        LogEvent('Including cascading sequences in HIS... OK');
      except
        on E: Exception do
        begin
          Tr.Rollback;
          Tr2.Rollback;
          raise EgsDBSqueeze.Create(E.Message);
        end;
      end;
    finally
      LineDocTbls.Free;
      CrossLineTbls.Free;
      ReProcLineTbls.Free;
      LineSetTbls.Free;
      SelfFkFieldsListLine.Free;
      SelfFkFieldsList2.Free;
      ExcFKTbls.Free;
      FkFieldsList.Free;
      FkFieldsList2.Free;
      FkFieldsList3.Free;
      FkFieldsListLine.Free;
      CascadeProcTbls.Free;
      ProcTblsNamesList.Free;
      TblsNamesList.Free;
      AllProcessedTblsNames.Free;
      LineTblsList.Free;
      AllProc.Free;
      LinePosList.Free;
      ReProc.Free;
      ReProcAll.Free;
      TmpList.Free;
      q.Free;
      q2.Free;
      q3.Free;
      q4.Free;
      q5.Free;
      Tr.Free;
      Tr2.Free;
    end;
  end;

  function ExistField(FieldName: String; TableName: String): Boolean;
  var
    q: TIBSQL;
    Tr: TIBTransaction;
  begin
    Result := False;
    q := TIBSQL.Create(nil);
    Tr := TIBTransaction.Create(nil);
    try
      Tr.DefaultDatabase := FIBDatabase;
      Tr.StartTransaction;

      q.Transaction := Tr;

      q.SQL.Text :=
        'SELECT * ' +                       #13#10 +
        '  FROM RDB$RELATION_FIELDS ' +     #13#10 +
        ' WHERE RDB$RELATION_NAME = :RN ' + #13#10 +
        '   AND RDB$FIELD_NAME = :FN ';
      q.ParamByName('RN').AsString := UpperCase(Trim(TableName));
      q.ParamByName('FN').AsString := UpperCase(Trim(FieldName));
      ExecSqlLogEvent(q, 'CreateInvBalance');

      Result := not q.EOF;

      Tr.Commit;
    finally
      q.Free;
      Tr.Free;
    end;
  end;

begin
  Assert(Connected);

  Tr := TIBTransaction.Create(nil);
  q := TIBSQL.Create(nil);
  try
    Tr.DefaultDatabase := FIBDatabase;
    Tr.StartTransaction;

    q.Transaction := Tr;

    SetBlockTriggerActive(False);  

    LogEvent('[test] DELETE FROM INV_BALANCE...');
    q.SQL.Text :=
      'DELETE FROM INV_BALANCE';
    ExecSqlLogEvent(q, 'CreateHIS_IncludeInHIS');
    LogEvent('[test] DELETE FROM INV_BALANCE');


    LogEvent('[test] DELETE FROM AC_RECORD...');
    q.SQL.Text :=
      'DELETE FROM gd_ruid gr ' +
      'WHERE EXISTS( ' +
      '  SELECT * ' +
      '  FROM AC_RECORD ar ' +
      '  WHERE ar.id = gr.xid ' +
      '    AND ar.recorddate < :ClosingDate ';
    if FOnlyCompanySaldo then
      q.SQL.Add(' ' +
        'AND ar.companykey = ' + IntToStr(FCompanykey));
    q.SQL.Add(')');
    q.ParamByName('ClosingDate').AsDateTime := FClosingDate;
    ExecSqlLogEvent(q, 'CreateHIS_IncludeInHIS');

    q.SQL.Text :=
      'DELETE FROM AC_RECORD ' +                          #13#10 +
      ' WHERE recorddate < :ClosingDate ';
    if FOnlyCompanySaldo then
      q.SQL.Add(' ' +
        'AND companykey = ' + IntToStr(FCompanykey));
    q.ParamByName('ClosingDate').AsDateTime := FClosingDate;
    ExecSqlLogEvent(q, 'CreateHIS_IncludeInHIS');
    LogEvent('[test] DELETE FROM AC_RECORD... OK');
    Tr.Commit;
    Tr.StartTransaction;

    LogEvent('Including PKs In HugeIntSet... ');

    CreateHIS(1);

    // ����� ���� � � ������ ���������� ������������� ������ ��������
    
    q.SQL.Text :=
      'SELECT SUM(g_his_include(1, id)) AS Kolvo ' + #13#10 +
      '  FROM gd_document ' +                             #13#10 +
      ' WHERE parent IS NULL ' +                          #13#10 +
      '   AND ((documentdate >= :Date) ';
    if Assigned(FDocTypesList) then
    begin  
      q.SQL.Add(' ' + 
        ' OR (documentdate < :Date ');
      if not FDoProcDocTypes then
        q.SQL.Add(' ' +
          '   AND documenttypekey IN(' + FDocTypesList.CommaText + ')) ')
      else
        q.SQL.Add(' ' +
          '   AND documenttypekey NOT IN(' + FDocTypesList.CommaText + ')) ');
    end;
    q.SQL.Add(')');

    q.ParamByName('Date').AsDateTime := FClosingDate;
    ExecSqlLogEvent(q, 'CreateHIS_IncludeInHIS');
    q.Close;

    LogEvent('[test] DELETE FROM INV_MOVEMENT...');
    q.SQL.Text :=
      'DELETE FROM gd_ruid gr ' +
      'WHERE EXISTS(' +
      '  SELECT * ' +
      '  FROM inv_movement im ' +
      '  WHERE im.id = gr.xid ' +
      '    AND g_his_has(1, im.documentkey)=0' +
      ')';
    ExecSqlLogEvent(q, 'CreateHIS_IncludeInHIS');

    q.SQL.Text :=
      'DELETE FROM INV_MOVEMENT ' +                          #13#10 +
      ' WHERE g_his_has(1, documentkey)=0 ';
    ExecSqlLogEvent(q, 'CreateHIS_IncludeInHIS');
    LogEvent('[test] DELETE FROM INV_MOVEMENT... OK');


    CreateHIS(2); // inv_card.id �� ������� ���� ������


    IncludeCascadingSequences('GD_DOCUMENT');


    LogEvent(Format('AFTER COUNT in HIS(1) with CASCADE: %d', [GetCountHIS(1)]));
    q.SQL.Text :=
      'SELECT COUNT(id) AS Kolvo ' +                         #13#10 +
      '  FROM gd_document ' +                                #13#10 +
      ' WHERE g_his_has(1, id) = 1';
    ExecSqlLogEvent(q, 'CreateHIS_IncludeInHIS');
    LogEvent(Format('COUNT DOCS in HIS: %d', [q.FieldByName('Kolvo').AsInteger]));
    q.Close;

    LogEvent('Including PKs In HugeIntSet... OK');
    if FCurrentProgressStep < 33*PROGRESS_STEP then
      ProgressMsgEvent('', ((33*PROGRESS_STEP) - FCurrentProgressStep));

    q.SQL.Text :=                                                               /// tod� ��������� ��������
      'DELETE FROM gd_ruid gr ' +
      'WHERE EXISTS(' +
      '  SELECT * ' +
      '  FROM gd_document doc ' +
       ' WHERE doc.id = gr.xid ' +
       '   AND g_his_has(1, doc.id)=0 ' +
      '    AND id >= 147000000 ' +
      ')';
    ExecSqlLogEvent(q, 'CreateHIS_IncludeInHIS');

    for I:=1 to FCascadeTbls.Count-1 do
    begin
      if ExistField('ID', FCascadeTbls.Names[I]) then
      begin
        if AnsiPos('||', FCascadeTbls.Values[FCascadeTbls.Names[I]]) = 0 then
          q.SQL.Text :=
            'DELETE FROM gd_ruid gr ' +
            'WHERE EXISTS(' +
            '  SELECT * ' +
            '  FROM ' + FCascadeTbls.Names[I]  + ' rln ' +                                     #13#10 +
            '  WHERE rln.id = gr.xid ' +
            '    AND (g_his_has(1, rln.' + FCascadeTbls.Values[FCascadeTbls.Names[I]] + ')=0 ' + #13#10 +
            '    AND rln.' + FCascadeTbls.Values[FCascadeTbls.Names[I]] + ' >= 147000000) '
        else begin
          if FCascadeTbls.Names[I] = 'INV_CARD' then
            q.SQL.Text :=
              'DELETE FROM gd_ruid gr ' +
              'WHERE EXISTS(' +
              '  SELECT * ' +
              '  FROM inv_card rln ' +                                     #13#10 +
              '  WHERE rln.id = gr.xid ' +
              '    AND g_his_has(2, rln.id)=0 ' + #13#10 +
              '    AND rln.id >= 147000000) '
          else
            q.SQL.Text :=
              'DELETE FROM gd_ruid gr ' +
              'WHERE EXISTS(' +
              '  SELECT * ' +
              '  FROM ' + FCascadeTbls.Names[I]  + ' rln ' +                                     #13#10 +
              '  WHERE rln.id = gr.xid ' +
              '    AND (rln.' +  StringReplace(FCascadeTbls.Values[FCascadeTbls.Names[I]], '||', ' >= 147000000) AND (rln.', [rfReplaceAll, rfIgnoreCase]) + ' >= 147000000) ' + #13#10 +
              '    AND (g_his_has(1, rln.' + StringReplace(FCascadeTbls.Values[FCascadeTbls.Names[I]], '||', ')=0 OR g_his_has(1, rln.', [rfReplaceAll, rfIgnoreCase]) + ')=0 )) ';
        end;

        ExecSqlLogEvent(q, 'CreateHIS_IncludeInHIS');
      end;
    end;

    if RelationExist2('AC_ENTRY_BALANCE', Tr) then
    begin
      q.SQL.Text :=
        'SELECT ' +                                             #13#10 +
        '  rdb$generator_name ' +                               #13#10 +
        'FROM ' +                                               #13#10 +
        '  rdb$generators ' +                                   #13#10 +
        'WHERE ' +                                              #13#10 +
        '  rdb$generator_name = ''GD_G_ENTRY_BALANCE_DATE''';
      ExecSqlLogEvent(q, 'CreateHIS_IncludeInHIS');
      if q.RecordCount <> 0 then
      begin
        q.Close;
        q.SQL.Text :=
          'SELECT ' +                                                                                    #13#10 +
          '  (GEN_ID(gd_g_entry_balance_date, 0) - ' + IntToStr(15018) + ') AS CalculatedBalanceDate ' + #13#10 +
          'FROM rdb$database ';
        ExecSqlLogEvent(q, 'CreateHIS_IncludeInHIS');
        if q.FieldByName('CalculatedBalanceDate').AsInteger > 0 then
        begin
          if q.FieldByName('CalculatedBalanceDate').AsInteger < FClosingDate then
          begin
            q.Close;
            q.SQL.Text :=
              'DELETE FROM GD_RUID gr ' +   #13#10 +
              'WHERE EXISTS( ' +            #13#10 +
              '  SELECT * FROM ac_entry_balance ae WHERE ae.id = gr.xid)';
            ExecSqlLogEvent(q, 'CreateHIS_IncludeInHIS');
          end;
        end;
      end;
      q.Close;
    end;
    Tr.Commit;
  finally
    q.Free;
    Tr.Free;
  end;
end;


procedure TgsDBSqueeze.DeleteDocuments_DeleteHIS;
var
  q: TIBSQL;
  Tr: TIBTransaction;
  I: Integer;
begin
  Assert(Connected);

  Tr := TIBTransaction.Create(nil);
  q := TIBSQL.Create(nil);
  try
    Tr.DefaultDatabase := FIBDatabase;
    Tr.StartTransaction;

    q.Transaction := Tr;

    LogEvent('Deleting from DB... ');
    LogEvent(Format('COUNT in HIS(1): %d', [GetCountHIS(1)]));

    q.SQL.Text :=
      'DELETE FROM GD_DOCUMENT ' +                              #13#10 +
      ' WHERE g_his_has(1, id)=0 ' +                            #13#10 +
      '   AND id >= 147000000';
    ExecSqlLogEvent(q, 'DeleteDocuments_DeleteHIS');

    for I:=1 to FCascadeTbls.Count-1 do
    begin
      if AnsiPos('||', FCascadeTbls.Values[FCascadeTbls.Names[I]]) = 0 then
        q.SQL.Text :=
          'DELETE FROM ' + FCascadeTbls.Names[I]  +                                      #13#10 +
          ' WHERE (g_his_has(1,' + FCascadeTbls.Values[FCascadeTbls.Names[I]] + ')=0 ' + #13#10 +
          '   AND ' + FCascadeTbls.Values[FCascadeTbls.Names[I]] + ' >= 147000000) '
      else begin
        if FCascadeTbls.Names[I] = 'INV_CARD' then           
          q.SQL.Text :=
            'DELETE FROM inv_card ' +                           #13#10 +
            'WHERE g_his_has(2, id)=0 ' + #13#10 +
            '  AND id >= 147000000 '
        else
          q.SQL.Text :=
            'DELETE FROM ' + FCascadeTbls.Names[I] +            #13#10 +
            ' WHERE (' +  StringReplace(FCascadeTbls.Values[FCascadeTbls.Names[I]], '||', ' >= 147000000) AND (',[rfReplaceAll, rfIgnoreCase]) + ' >= 147000000) ' + #13#10 +
            '   AND (g_his_has(1,' + StringReplace(FCascadeTbls.Values[FCascadeTbls.Names[I]], '||', ')=0 OR g_his_has(1,',[rfReplaceAll, rfIgnoreCase]) + ')=0 )';
      end;

      ExecSqlLogEvent(q, 'DeleteDocuments_DeleteHIS');
    end;

    Tr.Commit;

    DestroyHIS(2);
    DestroyHIS(1);
    //DestroyHIS(0);

    SetBlockTriggerActive(True);
   
    LogEvent('Deleting from DB... OK');
  finally
    q.Free;
    Tr.Free;
  end;
end;

function TgsDBSqueeze.GetConnected: Boolean;
begin
  Result := FIBDatabase.Connected;
end;

procedure TgsDBSqueeze.PrepareDB;
var
  Tr: TIBTransaction;
  q: TIBSQL;

  procedure PrepareTriggers;
  begin
    q.SQL.Text :=
      'EXECUTE BLOCK ' +                                                                #13#10 +
      'AS ' +                                                                           #13#10 +
      '  DECLARE VARIABLE TN CHAR(31); ' +                                              #13#10 +
      'BEGIN ' +                                                                        #13#10 +
      '  FOR ' +                                                                        #13#10 +
      '    SELECT t.rdb$trigger_name ' +                                                #13#10 +
      '    FROM rdb$triggers t ' +                                                      #13#10 +
     /// '      JOIN DBS_TMP_PROCESSED_TABLES p ON p.relation_name = t.RDB$RELATION_NAME ' +  #13#10 +                                                   ////test
      '    WHERE ((t.rdb$trigger_inactive = 0) OR (t.rdb$trigger_inactive IS NULL)) ' + #13#10 +
      '      AND ((t.RDB$SYSTEM_FLAG = 0) OR (t.RDB$SYSTEM_FLAG IS NULL)) ' +           #13#10 +
      //'      AND RDB$TRIGGER_NAME NOT IN (SELECT RDB$TRIGGER_NAME FROM RDB$CHECK_CONSTRAINTS) ' +
      '    INTO :TN ' +                                                                 #13#10 +
      '  DO ' +                                                                         #13#10 +
      '  BEGIN ' +                                                                      #13#10 +
      '    IN AUTONOMOUS TRANSACTION DO ' +                                             #13#10 +
      '      EXECUTE STATEMENT ''ALTER TRIGGER '' || :TN || '' INACTIVE ''; ' +         #13#10 +
      '  END ' +                                                                        #13#10 +
      'END';
    ExecSqlLogEvent(q, 'PrepareTriggers');
    Tr.Commit;
    Tr.StartTransaction;
    
    LogEvent('Triggers deactivated.');
  end;

  procedure PrepareIndices;
  begin
    q.SQL.Text :=
      'EXECUTE BLOCK ' +                                                        #13#10 +
      'AS ' +                                                                   #13#10 +
      '  DECLARE VARIABLE N CHAR(31); ' +                                       #13#10 +
      'BEGIN ' +                                                                #13#10 +
      '  FOR ' +                                                                #13#10 +
     '    SELECT i.rdb$index_name ' +                                            #13#10 +
      '    FROM rdb$indices i ' +                                                 #13#10 +
    ///  '      JOIN DBS_TMP_PROCESSED_TABLES p ON p.relation_name = i.RDB$RELATION_NAME ' +  #13#10 +
      '    WHERE ((i.rdb$index_inactive = 0) OR (i.rdb$index_inactive IS NULL)) ' + #13#10 +
      '      AND ((i.RDB$SYSTEM_FLAG = 0) OR (i.RDB$SYSTEM_FLAG IS NULL)) ' +       #13#10 +
     /// '      AND ((rdb$index_name NOT LIKE ''DBS_%'') AND (rdb$index_name NOT LIKE ''PK_DBS_%'')) ' + #13#10 +        ///test
      '      AND i.rdb$relation_name NOT LIKE ''DBS_%'' ' +
      '      AND ((NOT i.rdb$index_name LIKE ''RDB$%'') ' +                       #13#10 +
      '        OR ((i.rdb$index_name LIKE ''RDB$PRIMARY%'') ' +                   #13#10 +
      '        OR (i.rdb$index_name LIKE ''RDB$FOREIGN%'')) ' +                   #13#10 +
      '      ) ' +                                                              #13#10 +     

   {   //////////////////////
      '    SELECT ii.rdb$index_name ' + #13#10 +
      '    FROM rdb$indices ii ' + #13#10 +
      '    WHERE ((ii.rdb$index_inactive = 0) OR (ii.rdb$index_inactive IS NULL)) ' + #13#10 +
      '      AND ((ii.RDB$SYSTEM_FLAG = 0) OR (ii.RDB$SYSTEM_FLAG IS NULL)) ' + #13#10 +
      '      AND ii.rdb$relation_name NOT LIKE ''DBS_%'' ' + #13#10 +
      '      AND ((NOT ii.rdb$index_name LIKE ''RDB$%'') ' + #13#10 +
      '        OR ((ii.rdb$index_name LIKE ''RDB$PRIMARY%'') ' + #13#10 +
      '        OR (ii.rdb$index_name LIKE ''RDB$FOREIGN%'')) ' + #13#10 +
      '      ) ' + #13#10 +
      '      AND NOT EXISTS ( ' + #13#10 +
      '        SELECT * ' + #13#10 +
      '        FROM RDB$RELATION_CONSTRAINTS c ' + #13#10 +
      '          JOIN ( ' + #13#10 +
      '          	SELECT  ' + #13#10 +
      '          	  inx.RDB$INDEX_NAME,                   ' + #13#10 +
      '              LIST(TRIM(inx.RDB$FIELD_NAME)) as List_Fields    ' + #13#10 +
      '            FROM  ' + #13#10 +
      '              RDB$INDEX_SEGMENTS inx                       ' + #13#10 +
      '            GROUP BY  ' + #13#10 +
      '              inx.RDB$INDEX_NAME                      ' + #13#10 +
      '          ) i ON c.RDB$INDEX_NAME = i.RDB$INDEX_NAME  ' + #13#10 +
      '        WHERE ' + #13#10 +
      '          c.RDB$INDEX_NAME = ii.rdb$index_name ' + #13#10 +
      '          AND EXISTS( ' + #13#10 +
      '              SELECT * ' + #13#10 +
      '              FROM   RDB$RELATION_CONSTRAINTS cc  ' + #13#10 +
      '                JOIN RDB$REF_CONSTRAINTS refcc  ' + #13#10 +
      '                  ON cc.RDB$CONSTRAINT_NAME = refcc.RDB$CONSTRAINT_NAME  ' + #13#10 +
      '                JOIN RDB$RELATION_CONSTRAINTS cc2  ' + #13#10 +
      '                  ON refcc.RDB$CONST_NAME_UQ = cc2.RDB$CONSTRAINT_NAME ' + #13#10 +
      '                JOIN rdb$index_segments isegc  ' + #13#10 +
      '                  ON isegc.rdb$index_name = cc.rdb$index_name  ' + #13#10 +
      '                JOIN rdb$index_segments ref_isegc  ' + #13#10 +
      '                  ON ref_isegc.rdb$index_name = cc2.rdb$index_name  ' + #13#10 +
      '              WHERE ' + #13#10 +
      '                cc2.RDB$RELATION_NAME = c.RDB$RELATION_NAME ' + #13#10 +
      '                AND cc.rdb$constraint_type = ''FOREIGN KEY'' ' + #13#10 +
      '                AND refcc.rdb$delete_rule IN(''SET NULL'', ''SET DEFAULT'')   ' + #13#10 +
      '                AND cc.rdb$constraint_name NOT LIKE ''RDB$%'' ' + #13#10 +
      '          ) ' + #13#10 +
      //'	      AND (c.rdb$constraint_type = ''PRIMARY KEY'' OR c.rdb$constraint_type = ''UNIQUE'')  ' + #13#10 +
      //'	      AND c.rdb$constraint_name NOT LIKE ''RDB$%''    ' + #13#10 +

      '        UNION ' + #13#10 +

      '        SELECT * ' + #13#10 +
      '        FROM RDB$RELATION_CONSTRAINTS c                     ' + #13#10 +
      '          JOIN ( ' + #13#10 +
      '          	SELECT  ' + #13#10 +
      '          	  inx.RDB$INDEX_NAME,                   ' + #13#10 +
      '              LIST(TRIM(inx.RDB$FIELD_NAME)) as List_Fields    ' + #13#10 +
      '            FROM  ' + #13#10 +
      '              RDB$INDEX_SEGMENTS inx                       ' + #13#10 +
      '            GROUP BY  ' + #13#10 +
      '              inx.RDB$INDEX_NAME                      ' + #13#10 +
      '          ) i ON c.RDB$INDEX_NAME = i.RDB$INDEX_NAME  ' + #13#10 +
      '        WHERE ' + #13#10 +
      '          c.RDB$INDEX_NAME = ii.rdb$index_name ' + #13#10 +
      '          AND EXISTS( ' + #13#10 +
      '            SELECT * ' + #13#10 +
      '            FROM  ' + #13#10 +
      '              RDB$RELATION_CONSTRAINTS cc  ' + #13#10 +
      '              JOIN RDB$REF_CONSTRAINTS refcc  ' + #13#10 +
      '                ON cc.RDB$CONSTRAINT_NAME = refcc.RDB$CONSTRAINT_NAME  ' + #13#10 +
      '              JOIN RDB$RELATION_CONSTRAINTS cc2  ' + #13#10 +
      '                ON refcc.RDB$CONST_NAME_UQ = cc2.RDB$CONSTRAINT_NAME ' + #13#10 +
      '              JOIN rdb$index_segments isegc  ' + #13#10 +
      '                ON isegc.rdb$index_name = cc.rdb$index_name  ' + #13#10 +
      '              JOIN rdb$index_segments ref_isegc  ' + #13#10 +
      '                ON ref_isegc.rdb$index_name = cc2.rdb$index_name  ' + #13#10 +
      '            WHERE ' + #13#10 +
      '              cc2.RDB$RELATION_NAME = c.RDB$RELATION_NAME ' + #13#10 +
      '              AND cc.rdb$constraint_type = ''FOREIGN KEY'' ' + #13#10 +
      '              AND refcc.rdb$delete_rule IN(''SET NULL'', ''SET DEFAULT'')   ' + #13#10 +
      '              AND cc.rdb$constraint_name NOT LIKE ''RDB$%'' ' + #13#10 +
      '          ) ' + #13#10 +
      //'          AND (c.rdb$constraint_type = ''PRIMARY KEY'' OR c.rdb$constraint_type = ''UNIQUE'')  ' + #13#10 +
      //'          AND c.rdb$constraint_name NOT LIKE ''RDB$%'' ' + #13#10 +
      '      ) ' + #13#10 +
   }

      '    INTO :N ' +                                                          #13#10 +
      '  DO ' +                                                                 #13#10 +
      '    EXECUTE STATEMENT ''ALTER INDEX '' || :N || '' INACTIVE ''; ' +      #13#10 +
      'END';
    ExecSqlLogEvent(q, 'PrepareIndices');
    Tr.Commit;
    Tr.StartTransaction;
    LogEvent('Indices deactivated.');
  end;


  procedure PreparePkUniqueConstraints;
  begin
    q.SQL.Text :=
      'EXECUTE BLOCK ' +                                                        #13#10 +
      'AS ' +                                                                   #13#10 +
      '  DECLARE VARIABLE CN CHAR(31); ' +                                      #13#10 +
      '  DECLARE VARIABLE RN CHAR(31); ' +                                      #13#10 +
      'BEGIN ' +                                                                #13#10 +
      '  FOR ' +                                                                #13#10 +
      '    SELECT ' +                                                           #13#10 +
      '      pc.constraint_name, ' +                                            #13#10 +
      '      pc.relation_name ' +                                               #13#10 +
      '    FROM ' +                                                             #13#10 +
      '      dbs_pk_unique_constraints pc ' +                                   #13#10 +
   ///   '      JOIN DBS_TMP_PROCESSED_TABLES p ON p.relation_name = pc.RELATION_NAME ' +  #13#10 +
      '    WHERE ' +
      '      pc.relation_name NOT LIKE ''DBS_%'' ' +                            #13#10 +
////////////////////
{           '  AND NOT EXISTS( ' +                                              #13#10 +
      '       SELECT * ' +                                                      #13#10 +
      '       FROM rdb$relation_constraints cc  ' +                             #13#10 +
      '         JOIN RDB$REF_CONSTRAINTS refcc  ' +                             #13#10 +
      '           ON cc.rdb$constraint_name = refcc.rdb$constraint_name  ' +    #13#10 +
      '         JOIN RDB$RELATION_CONSTRAINTS cc2  ' +                          #13#10 +
      '           ON refcc.rdb$const_name_uq = cc2.rdb$constraint_name ' +      #13#10 +
      '         JOIN RDB$INDEX_SEGMENTS isegc  ' +                              #13#10 +
      '           ON isegc.rdb$index_name = cc.rdb$index_name  ' +              #13#10 +
      '         JOIN RDB$INDEX_SEGMENTS ref_isegc  ' +                          #13#10 +
      '           ON ref_isegc.rdb$index_name = cc2.rdb$index_name  ' +         #13#10 +
      '       WHERE ' +                                                         #13#10 +
      '         cc2.rdb$relation_name = pc.relation_name ' +                    #13#10 +
      '         AND cc.rdb$constraint_type = ''FOREIGN KEY'' ' +                #13#10 +
      '         AND refcc.rdb$delete_rule IN(''SET NULL'', ''SET DEFAULT'') ' + #13#10 +
      '         AND cc.rdb$constraint_name NOT LIKE ''RDB$%'' ' +               #13#10 +
      '   ) ' +                                                                 #13#10 +         }
///////////////////
 {
      ////////////////////
      '      AND NOT EXISTS( ' +                                                #13#10 +
      '        SELECT * ' + 							#13#10 +
      '        FROM dbs_fk_constraints cc ' +					#13#10 +
      '        WHERE ' +							#13#10 +
      '          cc.ref_relation_name = pc.relation_name ' +			#13#10 +
      '          AND cc.delete_rule IN(''SET NULL'', ''SET DEFAULT'') ' +       #13#10 +
      '          AND cc.constraint_name NOT LIKE ''RDB$%'' ' +               	#13#10 +
      '      ) ' +                                                              #13#10 +
      /////////////////// }
      '    INTO :CN, :RN ' +                                                              #13#10 +
      '  DO ' +                                                                           #13#10 +
      '    EXECUTE STATEMENT ''ALTER TABLE '' || :RN || '' DROP CONSTRAINT '' || :CN; ' + #13#10 +
      'END';
    ExecSqlLogEvent(q, 'PreparePkUniqueConstraints');
    Tr.Commit;
    Tr.StartTransaction;
    LogEvent('PKs&UNIQs dropped.');
  end;

  procedure PrepareFKConstraints;
  begin
    q.SQL.Text :=
      'EXECUTE BLOCK ' +                                                #13#10 +
      'AS ' +                                                           #13#10 +
      '  DECLARE VARIABLE CN CHAR(31); ' +                              #13#10 +
      '  DECLARE VARIABLE RN CHAR(31); ' +                              #13#10 +
      'BEGIN ' +                                                        #13#10 +
      '  FOR ' +                                                        #13#10 +
      '    SELECT ' +                                                   #13#10 +
      '      c.constraint_name, ' +                                     #13#10 +
      '      c.relation_name ' +                                        #13#10 +
      '    FROM ' +                                                     #13#10 +
      '      dbs_fk_constraints c ' +                                   #13#10 +
      ///'      JOIN DBS_TMP_PROCESSED_TABLES p ON p.relation_name = c.relation_name ' +  #13#10 +
      '    WHERE ' +                                                    #13#10 +
      '      c.constraint_name NOT LIKE ''DBS_%'' ' +                   #13#10 +
   //   '      AND c.delete_rule NOT IN(''SET NULL'', ''SET DEFAULT'') ' +#13#10 +
      '    INTO :CN, :RN ' +                                            #13#10 +
      '  DO ' +                                                                           #13#10 +
      '    EXECUTE STATEMENT ''ALTER TABLE '' || :RN || '' DROP CONSTRAINT '' || :CN; ' + #13#10 +
      'END';
    ExecSqlLogEvent(q, 'PrepareFKConstraints');

    Tr.Commit;
    Tr.StartTransaction;

    LogEvent('FKs dropped.');
  end;

begin
  Assert(Connected);

  Tr := TIBTransaction.Create(nil);
  q := TIBSQL.Create(nil);
  try
    LogEvent('DB preparation...');

    SetBlockTriggerActive(True);

    Tr.DefaultDatabase := FIBDatabase;
    Tr.StartTransaction;

    q.Transaction := Tr;
    try
      PrepareFKConstraints;
      PreparePkUniqueConstraints;
      PrepareTriggers;
      PrepareIndices;                                    ////////////////

      Tr.Commit;
      LogEvent('DB preparation... OK');
    except
      on E: Exception do
      begin
        //Tr.Rollback;
        raise;
      end;
    end
  finally
    q.Free;
    Tr.Free;
  end;
end;

procedure TgsDBSqueeze.SaveMetadata;
var
  Tr: TIBTransaction;
  q: TIBSQL;
begin
  Assert(Connected);
  
  Tr := TIBTransaction.Create(nil);
  q := TIBSQL.Create(nil);
  try
    Tr.DefaultDatabase := FIBDatabase;
    Tr.StartTransaction;

    q.Transaction := Tr;

    // inactive triggers
    q.SQL.Text :=
      'INSERT INTO DBS_INACTIVE_TRIGGERS (trigger_name) ' +                          #13#10 +
      'SELECT rdb$trigger_name ' +                                                   #13#10 +
      '  FROM rdb$triggers ' +                                                       #13#10 +
      ' WHERE (rdb$trigger_inactive <> 0) AND (rdb$trigger_inactive IS NOT NULL) ' + #13#10 +
      '   AND ((rdb$system_flag = 0) OR (rdb$system_flag IS NULL)) ';
    ExecSqlLogEvent(q, 'SaveMetadata');

    // inactive indices
    q.SQL.Text :=
      'INSERT INTO DBS_INACTIVE_INDICES (index_name) ' +                             #13#10 +
      'SELECT rdb$index_name ' +                                                     #13#10 +
      '  FROM rdb$indices ' +                                                        #13#10 +
      ' WHERE (rdb$index_inactive <> 0) AND (rdb$index_inactive IS NOT NULL) ' +     #13#10 +
      '   AND ((rdb$system_flag = 0) OR (rdb$system_flag IS NULL))';
    ExecSqlLogEvent(q, 'SaveMetadata');

    // PKs and Uniques constraints
    q.SQL.Text :=                                                   
      'INSERT INTO DBS_PK_UNIQUE_CONSTRAINTS ( ' +                              #13#10 +
      '  relation_name, ' +                                                     #13#10 +
      '  constraint_name, ' +                                                   #13#10 +
      '  constraint_type, ' +                                                   #13#10 +
      '  list_fields ) ' +                                                      #13#10 +
      'SELECT ' +                                                               #13#10 +
      '   c.rdb$relation_name, ' +                                              #13#10 +
      '   c.rdb$constraint_name, ' +                                            #13#10 +
      '   c.rdb$constraint_type, ' +                                            #13#10 +
      '   i.List_Fields ' +                                                     #13#10 +
      ' FROM ' +                                                                #13#10 +
      '   rdb$relation_constraints c ' +                                        #13#10 +
      '   JOIN (SELECT inx.rdb$index_name, ' +                                  #13#10 +
      '     LIST(TRIM(inx.rdb$field_name)) AS List_Fields ' +                   #13#10 +
      '     FROM rdb$index_segments inx ' +                                     #13#10 +
      '     GROUP BY inx.rdb$index_name ' +                                     #13#10 +
      '   ) i ON c.rdb$index_name = i.rdb$index_name ' +                        #13#10 +
      ' WHERE ' +                                                               #13#10 +
{     '   NOT EXISTS( ' +                                                       #13#10 +
      '       SELECT * ' +                                                      #13#10 +
      '       FROM rdb$relation_constraints cc  ' +                             #13#10 +
      '         JOIN RDB$REF_CONSTRAINTS refcc  ' +                             #13#10 +
      '           ON cc.rdb$constraint_name = refcc.rdb$constraint_name  ' +    #13#10 +
      '         JOIN RDB$RELATION_CONSTRAINTS cc2  ' +                          #13#10 +
      '           ON refcc.rdb$const_name_uq = cc2.rdb$constraint_name ' +      #13#10 +
      '         JOIN RDB$INDEX_SEGMENTS isegc  ' +                              #13#10 +
      '           ON isegc.rdb$index_name = cc.rdb$index_name  ' +              #13#10 +
      '         JOIN RDB$INDEX_SEGMENTS ref_isegc  ' +                          #13#10 +
      '           ON ref_isegc.rdb$index_name = cc2.rdb$index_name  ' +         #13#10 +
      '       WHERE ' +                                                         #13#10 +
      '         cc2.rdb$relation_name = c.rdb$relation_name ' +                 #13#10 +
      '         AND cc.rdb$constraint_type = ''FOREIGN KEY'' ' +                #13#10 +
      '         AND refcc.rdb$delete_rule IN(''SET NULL'', ''SET DEFAULT'') ' + #13#10 +
      '         AND cc.rdb$constraint_name NOT LIKE ''RDB$%'' ' +               #13#10 +
      '   ) ' +                                                                 #13#10 +   }
      '   (c.rdb$constraint_type = ''PRIMARY KEY'' OR c.rdb$constraint_type = ''UNIQUE'')  ' + #13#10 +
      '   AND c.rdb$constraint_name NOT LIKE ''RDB$%'' ';
    ExecSqlLogEvent(q, 'SaveMetadata');

    // ����� ������ � �� ���� PK, ������� �������� ��� ���������� �� ��������� HIS ��� ��������
    q.SQL.Text :=
      'INSERT INTO DBS_SUITABLE_TABLES ' +                                      #13#10 +
      'SELECT ' +                                                               #13#10 +
      '  pk.relation_name AS RN, ' +                                            #13#10 +
      '  pk.list_fields   AS FN ' +                                             #13#10 +
      'FROM ' +                                                                 #13#10 +
      '  dbs_pk_unique_constraints pk ' +                                       #13#10 +
      '  JOIN RDB$RELATION_FIELDS rf ' +                                        #13#10 +
      '    ON rf.rdb$relation_name = pk.relation_name ' +                       #13#10 +
      '      AND rf.rdb$field_name = pk.list_fields ' +                         #13#10 +
      '    JOIN RDB$FIELDS f ' +                                                #13#10 +
      '      ON f.rdb$field_name = rf.rdb$field_source ' +                      #13#10 +
      'WHERE ' +                                                                #13#10 +
      '  constraint_type = ''PRIMARY KEY'' ' +                                  #13#10 +
      '  AND list_fields NOT LIKE ''%,%'' ' +                                   #13#10 +
      '  AND f.rdb$field_type = 8 ';
    ExecSqlLogEvent(q, 'SaveMetadata');

    // FK constraints
    q.SQL.Text :=
      'INSERT INTO DBS_FK_CONSTRAINTS ( ' +                                     #13#10 +
      '  constraint_name, relation_name, ref_relation_name, ' +                 #13#10 +
      '  update_rule, delete_rule, list_fields, list_ref_fields) ' +            #13#10 +
      'SELECT ' +                                                               #13#10 +
      '  c.rdb$constraint_name         AS Constraint_Name, ' +                  #13#10 +
      '  c.rdb$relation_name           AS Relation_Name, ' +                    #13#10 +
      '  c2.rdb$relation_name          AS Ref_Relation_Name, ' +                #13#10 +
      '  refc.rdb$update_rule          AS Update_Rule, ' +                      #13#10 +
      '  refc.rdb$delete_rule          AS Delete_Rule, ' +                      #13#10 +
      '  LIST(iseg.rdb$field_name)     AS Fields, ' +                           #13#10 +
      '  LIST(ref_iseg.rdb$field_name) AS Ref_Fields ' +                        #13#10 +
      'FROM ' +                                                                 #13#10 +
      '  rdb$relation_constraints c ' +                                         #13#10 +
      '  JOIN RDB$REF_CONSTRAINTS refc ' +                                      #13#10 +
      '    ON c.rdb$constraint_name = refc.rdb$constraint_name ' +              #13#10 +
      '  JOIN RDB$RELATION_CONSTRAINTS c2 ' +                                   #13#10 +
      '    ON refc.rdb$const_name_uq = c2.rdb$constraint_name ' +               #13#10 +
      '  JOIN RDB$INDEX_SEGMENTS iseg ' +                                       #13#10 +
      '    ON iseg.rdb$index_name = c.rdb$index_name ' +                        #13#10 +
      '  JOIN RDB$INDEX_SEGMENTS ref_iseg ' +                                   #13#10 +
      '    ON ref_iseg.rdb$index_name = c2.rdb$index_name ' +                   #13#10 +
      'WHERE ' +                                                                #13#10 +
      '  c.rdb$constraint_type = ''FOREIGN KEY''  ' +                           #13#10 +
      ///'  AND refc.rdb$delete_rule NOT IN(''SET NULL'', ''SET DEFAULT'') ' +     #13#10 +
      '  AND c.rdb$constraint_name NOT LIKE ''RDB$%'' ' +                       #13#10 +
      'GROUP BY ' +                                                             #13#10 +
      '  1, 2, 3, 4, 5';
    ExecSqlLogEvent(q, 'SaveMetadata');

    Tr.Commit;
    Tr.StartTransaction;

{     // ��� ��������� ����������� ������, ������� �� �������������� �������� FKs

    //����� �������� cascade � ������ ������ dbs_restrict
    q.SQL.Text :=
      'INSERT INTO DBS_TMP2_FK_CONSTRAINTS ( ' +                                #13#10 +
      '  constraint_name, ' +                                                   #13#10 +
      '  relation_name, ' +                                                     #13#10 +
      '  ref_relation_name, ' +                                                 #13#10 +
      '  update_rule, delete_rule, list_fields, list_ref_fields) ' +            #13#10 +
      'SELECT ' +                                                               #13#10 +
      '  fc.rdb$constraint_name        AS Constraint_Name, ' +                  #13#10 +
      '  fc.rdb$relation_name          AS Relation_Name, ' +                    #13#10 +
      '  fc2.rdb$relation_name         AS Ref_Relation_Name, ' +                #13#10 +
      '  refc.rdb$update_rule          AS Update_Rule, ' +                      #13#10 +
      '  refc.rdb$delete_rule          AS Delete_Rule, ' +                      #13#10 +
      '  LIST(iseg.rdb$field_name)     AS Fields, ' +                           #13#10 +
      '  LIST(ref_iseg.rdb$field_name) AS Ref_Fields ' +                        #13#10 +
      'FROM ' +                                                                 #13#10 +
      '  rdb$relation_constraints fc ' +                                        #13#10 +
      '  JOIN RDB$REF_CONSTRAINTS refc ' +                                      #13#10 +
      '    ON fc.rdb$constraint_name = refc.rdb$constraint_name ' +             #13#10 +
      '  JOIN RDB$RELATION_CONSTRAINTS fc2 ' +                                  #13#10 +
      '    ON refc.rdb$const_name_uq = fc2.rdb$constraint_name ' +              #13#10 +
      '  JOIN RDB$INDEX_SEGMENTS iseg ' +                                       #13#10 +
      '    ON iseg.rdb$index_name = fc.rdb$index_name ' +                       #13#10 +
      '  JOIN RDB$INDEX_SEGMENTS ref_iseg ' +                                   #13#10 +
      '    ON ref_iseg.rdb$index_name = fc2.rdb$index_name ' +                  #13#10 +
      '  JOIN( ' +                                                              #13#10 +
      '    SELECT ' +                                                           #13#10 +
      '      c.rdb$relation_name, ' +                                           #13#10 +
      '      COUNT(i.rdb$field_name)   AS Kolvo, ' +                            #13#10 +
      '      SUM(f.rdb$field_type)     AS Summa, ' +                            #13#10 +
      '      i.rdb$index_name ' +                                               #13#10 + // ��� �����������
      '    FROM ' +                                                             #13#10 +
      '      rdb$relation_constraints c ' +                                     #13#10 +
      '      JOIN RDB$INDEX_SEGMENTS i ' +                                      #13#10 +
      '        ON i.rdb$index_name = c.rdb$index_name ' +                       #13#10 +
      '      JOIN RDB$RELATION_FIELDS rf ' +                                    #13#10 +
      '        ON rf.rdb$relation_name = c.rdb$relation_name ' +                #13#10 +
      '          AND rf.rdb$field_name = i.rdb$field_name ' +                   #13#10 +
      '        JOIN RDB$FIELDS f ' +                                            #13#10 +
      '          ON f.rdb$field_name = rf.rdb$field_source ' +                  #13#10 +
      '    WHERE ' +                                                                             #13#10 +
      '      (c.rdb$constraint_type = ''PRIMARY KEY'' OR c.rdb$constraint_type = ''UNIQUE'') ' + #13#10 +
      '      AND c.rdb$constraint_name NOT LIKE ''RDB$%'' ' +                                    #13#10 + ///TODO: ��������
      '    GROUP BY ' +                                                                          #13#10 +
      '      i.rdb$index_name, c.rdb$relation_name ' +                                           #13#10 +
      '    HAVING ' +                                                                            #13#10 +
      '      (COUNT(i.rdb$field_name) > 1) ' +                                                   #13#10 +
      '      OR ((COUNT(i.rdb$field_name) = 1) AND (SUM(f.rdb$field_type) <> 8)) ' +             #13#10 +
      '  )pc ON pc.rdb$relation_name = fc.rdb$relation_name ' +                                  #13#10 +
      'WHERE ' +                                                                #13#10 +
      '  fc.rdb$constraint_type = ''FOREIGN KEY''  ' +                          #13#10 +
      '  AND fc.rdb$constraint_name NOT LIKE ''RDB$%'' ' +                      #13#10 +
      '  AND refc.rdb$delete_rule = ''CASCADE'' ' +                             #13#10 +
      'GROUP BY ' +                                                             #13#10 +
      '  1, 2, 3, 4, 5 ' +                                                      #13#10 +
      ' ' +                                                                     #13#10 +
      'UNION ' +                                                                #13#10 +
      ' ' +                                                                     #13#10 +
      'SELECT ' +                                                               #13#10 +
      '  fc.rdb$constraint_name        AS Constraint_Name, ' +                  #13#10 +
      '  fc.rdb$relation_name          AS Relation_Name, ' +                    #13#10 +
      '  fc2.rdb$relation_name         AS Ref_Relation_Name, ' +                #13#10 +
      '  refc.rdb$update_rule          AS Update_Rule, ' +                      #13#10 +
      '  refc.rdb$delete_rule          AS Delete_Rule, ' +                      #13#10 +
      '  LIST(iseg.rdb$field_name)     AS Fields, ' +                           #13#10 +
      '  LIST(ref_iseg.rdb$field_name) AS Ref_Fields ' +                        #13#10 +
      'FROM ' +                                                                 #13#10 +
      '  rdb$relation_constraints fc ' +                                        #13#10 +
      '  JOIN RDB$REF_CONSTRAINTS refc ' +                                      #13#10 +
      '    ON fc.rdb$constraint_name = refc.rdb$constraint_name ' +             #13#10 +
      '  JOIN RDB$RELATION_CONSTRAINTS fc2 ' +                                  #13#10 +
      '    ON refc.rdb$const_name_uq = fc2.rdb$constraint_name ' +              #13#10 +
      '  JOIN RDB$INDEX_SEGMENTS iseg ' +                                       #13#10 +
      '    ON iseg.rdb$index_name = fc.rdb$index_name ' +                       #13#10 +
      '  JOIN RDB$INDEX_SEGMENTS ref_iseg ' +                                   #13#10 +
      '    ON ref_iseg.rdb$index_name = fc2.rdb$index_name ' +                  #13#10 +
      '  LEFT JOIN DBS_PK_UNIQUE_CONSTRAINTS pc ' +                             #13#10 +
      '    ON pc.relation_name = fc.rdb$relation_name ' +                       #13#10 +
      'WHERE ' +                                                                #13#10 +
      '  fc.rdb$constraint_type = ''FOREIGN KEY''  ' +                          #13#10 +
      '  AND fc.rdb$constraint_name NOT LIKE ''RDB$%'' ' +                      #13#10 +
      '  AND pc.relation_name IS NULL ' +                                       #13#10 +
      '  AND refc.rdb$delete_rule = ''CASCADE'' ' +                             #13#10 +
      'GROUP BY ' +                                                             #13#10 +
      '  1, 2, 3, 4, 5';
    ExecSqlLogEvent(q, 'SaveMetadata');

    Tr.Commit;
    Tr.StartTransaction;

    q.SQL.Text :=
      'INSERT INTO DBS_FK_CONSTRAINTS ( ' +                                     #13#10 +
      '  relation_name, ' +                                                     #13#10 +
      '  ref_relation_name, ' +                                                 #13#10 +
      '  constraint_name, ' +                                                   #13#10 +
      '  list_fields, list_ref_fields, update_rule, delete_rule) ' +            #13#10 +
      'SELECT ' +                                                               #13#10 +
      '  fc.relation_name, ' +                                                  #13#10 +
      '  fc.ref_relation_name, ' +                                              #13#10 +
      '  (''DBS_'' || fc.constraint_name) AS constraint_name, ' +               #13#10 +
      '  fc.list_fields, fc.list_ref_fields, ''RESTRICT'', ''RESTRICT'' ' +     #13#10 +
      'FROM ' +                                                                 #13#10 +
      '  dbs_fk_constraints fc ' +                                              #13#10 +
      '  JOIN( ' +                                                              #13#10 +
      '    SELECT ' +                                                           #13#10 +
      '      c.rdb$relation_name, ' +                                           #13#10 +
      '      COUNT(i.rdb$field_name) AS Kolvo, ' +                              #13#10 +
      '      SUM(f.rdb$field_type)   AS Summa, ' +                              #13#10 +
      '      i.rdb$index_name ' +                                               #13#10 +//��� �����������
      '    FROM ' +                                                             #13#10 +
      '      rdb$relation_constraints c ' +                                     #13#10 +
      '      JOIN RDB$INDEX_SEGMENTS i ' +                                      #13#10 +
      '        ON i.rdb$index_name = c.rdb$index_name ' +                       #13#10 +
      '      JOIN RDB$RELATION_FIELDS rf ' +                                    #13#10 +
      '        ON rf.rdb$relation_name = c.rdb$relation_name ' +                #13#10 +
      '          AND rf.rdb$field_name = i.rdb$field_name ' +                   #13#10 +
      '        JOIN RDB$FIELDS f ' +                                            #13#10 +
      '          ON f.rdb$field_name = rf.rdb$field_source ' +                  #13#10 +
      '    WHERE ' +                                                                             #13#10 +
      '      (c.rdb$constraint_type = ''PRIMARY KEY'' OR c.rdb$constraint_type = ''UNIQUE'') ' + #13#10 +
      '      AND c.rdb$constraint_name NOT LIKE ''RDB$%'' ' +                                    #13#10 +
      '    GROUP BY ' +                                                                          #13#10 +
      '      i.RDB$INDEX_NAME, c.RDB$RELATION_NAME ' +                                           #13#10 +
      '    HAVING ' +                                                                            #13#10 +
      '      (COUNT(i.RDB$FIELD_NAME) > 1) ' +                                                   #13#10 +
      '      OR ((COUNT(i.RDB$FIELD_NAME) = 1) AND (SUM(f.rdb$field_type) <> 8)) ' +             #13#10 +
      '  )pc ON pc.rdb$relation_name = fc.relation_name ' +                                      #13#10 +
      'WHERE ' +                                                                #13#10 +
      '  fc.delete_rule = ''CASCADE'' ' +                                       #13#10 +
      ' ' +                                                                     #13#10 +
      'UNION ' +                                                                #13#10 +
      ' ' +                                                                     #13#10 +
      'SELECT ' +                                                               #13#10 +
      '  fc.relation_name, ' +                                                  #13#10 +
      '  fc.ref_relation_name, ' +                                              #13#10 +
      '  (''DBS_'' || fc.constraint_name) AS constraint_name, ' +               #13#10 +
      '  fc.list_fields, fc.list_ref_fields, ''RESTRICT'', ''RESTRICT'' ' +     #13#10 +
      'FROM ' +                                                                 #13#10 +
      '  dbs_fk_constraints  fc ' +                                             #13#10 +
      '  LEFT JOIN DBS_PK_UNIQUE_CONSTRAINTS pc ' +                             #13#10 +
      '    ON pc.relation_name = fc.relation_name ' +                           #13#10 +
      'WHERE ' +                                                                #13#10 +
      '  pc.relation_name IS NULL ' +                                           #13#10 +
      '  AND fc.delete_rule = ''CASCADE'' ';
    ExecSqlLogEvent(q, 'SaveMetadata');
}

    // ��� ��������� ����������� AcSaldo                                                           ///TODO ����� �� ����

    q.SQL.Text :=
      'INSERT INTO DBS_FK_CONSTRAINTS ( ' +                                     #13#10 +
      '  relation_name, ' +                                                     #13#10 +
      '  ref_relation_name, ' +                                                 #13#10 +
      '  constraint_name, ' +                                                   #13#10 +
      '  list_fields, list_ref_fields, update_rule, delete_rule) ' +            #13#10 +
      'SELECT ' +                                                               #13#10 +
      '  ''DBS_TMP_AC_SALDO'', ' +                                              #13#10 +
      '  ref_relation_name, ' +                                                 #13#10 +
      '  (''DBS_1'' || constraint_name), ' +                                    #13#10 +
      '  list_fields, list_ref_fields, ''RESTRICT'', ''RESTRICT'' ' +           #13#10 +
      'FROM  ' +                                                                #13#10 +
      '  dbs_fk_constraints  ' +                                                #13#10 +
      'WHERE  ' +                                                               #13#10 +
      '  relation_name = ''AC_ENTRY'' ' +                                       #13#10 +
      '  AND list_fields LIKE ''USR$%''';
    ExecSqlLogEvent(q, 'SaveMetadata');

    // ����� ��������� �������� ����������� InvSaldo
    q.SQL.Text :=
      'INSERT INTO DBS_FK_CONSTRAINTS ( ' +                                     #13#10 +
      '  relation_name, ' +                                                     #13#10 +
      '  ref_relation_name, ' +                                                 #13#10 +
      '  constraint_name, ' +                                                   #13#10 +
      '  list_fields, list_ref_fields, update_rule, delete_rule) ' +            #13#10 +
      'VALUES( ' +
      '  ''DBS_TMP_INV_SALDO'', ' +
      '  ''INV_CARD'', ' +
      '  ''DBS1_INV_FK_MOVEMENT_CARDK'', ' +
      '  ''CARDKEY'', ''ID'', ''RESTRICT'', ''RESTRICT'')';
    ExecSqlLogEvent(q, 'SaveMetadata');
    Tr.Commit;
    LogEvent('Metadata saved.');
  finally
    q.Free;
    Tr.Free;
  end;
end;

procedure TgsDBSqueeze.RestoreDB;
var
  Tr: TIBTransaction;
  q: TIBSQL;

  procedure RestoreTriggers;
  begin
    q.SQL.Text :=
      'EXECUTE BLOCK ' +                                                                  #13#10 +
      'AS ' +                                                                             #13#10 +
      '  DECLARE VARIABLE TN CHAR(31); ' +                                                #13#10 +
      'BEGIN ' +                                                                          #13#10 +
      '  FOR ' +                                                                          #13#10 +
      '    SELECT ' +                                                                     #13#10 +
      '      t.rdb$trigger_name ' +                                                       #13#10 +
      '    FROM ' +                                                                       #13#10 +
      '      rdb$triggers t ' +                                                           #13#10 +
  ///    '      JOIN DBS_TMP_PROCESSED_TABLES  p ON p.relation_name = t.RDB$RELATION_NAME ' +  #13#10 +
      '      LEFT JOIN DBS_INACTIVE_TRIGGERS it ' +                                       #13#10 +
      '        ON it.trigger_name = t.rdb$trigger_name ' +                                #13#10 +
      '    WHERE ' +                                                                      #13#10 +
      '      ((t.rdb$trigger_inactive <> 0) AND (t.rdb$trigger_inactive IS NOT NULL)) ' + #13#10 +
      '      AND ((t.rdb$system_flag = 0) OR (t.rdb$system_flag IS NULL)) ' +             #13#10 +
      '      AND it.trigger_name IS NULL ' +                                              #13#10 +
      '    INTO :TN ' +                                                                   #13#10 +
      '  DO ' +                                                                           #13#10 +
      '    EXECUTE STATEMENT ''ALTER TRIGGER '' || :TN || '' ACTIVE ''; ' +               #13#10 +
      'END';
    ExecSqlLogEvent(q, 'RestoreTriggers');

    Tr.Commit;
    Tr.StartTransaction;

    LogEvent('Triggers reactivated.');
  end;

  procedure RestoreIndices;
  begin
    q.SQL.Text :=
      'EXECUTE BLOCK ' +                                                                  #13#10 +
      'AS ' +                                                                             #13#10 +
      '  DECLARE VARIABLE N CHAR(31); ' +                                                 #13#10 +
      'BEGIN ' +                                                                          #13#10 +
      '  FOR ' +                                                                          #13#10 +
      '    SELECT ' +                                                                     #13#10 +
      '      i.rdb$index_name ' +                                                         #13#10 +
      '    FROM ' +                                                                       #13#10 +
      '      rdb$indices i ' +                                                            #13#10 +
 ///     '      JOIN DBS_TMP_PROCESSED_TABLES p ON p.relation_name = i.RDB$RELATION_NAME ' +  #13#10 +
      '      LEFT JOIN DBS_INACTIVE_INDICES ii ' +                                        #13#10 +
      '        ON ii.index_name = i.rdb$index_name ' +                                    #13#10 +
      '    WHERE ((i.rdb$index_inactive <> 0) AND (i.rdb$index_inactive IS NOT NULL)) ' + #13#10 +
      '      AND ((i.rdb$system_flag = 0) OR (i.rdb$system_flag IS NULL)) ' +             #13#10 +
      '      AND ii.index_name IS NULL ' +                                                #13#10 +
      '    INTO :N ' +                                                                    #13#10 +
      '  DO ' +                                                                           #13#10 +
      '    EXECUTE STATEMENT ''ALTER INDEX '' || :N || '' ACTIVE ''; ' +                  #13#10 +
      'END';
    ExecSqlLogEvent(q, 'RestoreIndices');

    Tr.Commit;
    Tr.StartTransaction;

    LogEvent('Indices reactivated.');
  end;

  procedure RestorePkUniqueConstraints;
  begin
    q.SQL.Text :=
{      'EXECUTE BLOCK ' +                                                                       #13#10 +
      'AS ' +                                                                                  #13#10 +
      '  DECLARE VARIABLE S VARCHAR(16384); ' +                                                #13#10 +
      'BEGIN ' +                                                                               #13#10 +
      '  FOR ' +                                                                               #13#10 +
      '    SELECT ''ALTER TABLE '' || c.relation_name || '' ADD CONSTRAINT '' || ' +             #13#10 +
      '      c.constraint_name || '' '' || c.constraint_type ||'' ('' || c.list_fields || '') '' ' + #13#10 +
      '    FROM dbs_pk_unique_constraints c ' +                                                  #13#10 +
  ///    '      JOIN DBS_TMP_PROCESSED_TABLES p ON p.relation_name = c.RELATION_NAME ' +  #13#10 +
      '    WHERE c.relation_name NOT LIKE ''DBS_%'' ' +                   #13#10 +
      '    INTO :S ' +                                                  #13#10 +
      '  DO BEGIN ' +                                                   #13#10 +
      '    EXECUTE STATEMENT :S; ' +                                    #13#10 +  /// WITH AUTONOMOUS TRANSACTION
      '    when any DO ' +                                              #13#10 +
      '    BEGIN ' +                                                    #13#10 +
      '      IF (sqlcode <> 0) THEN ' +                                 #13#10 +
      '        S = S || '' An SQL error occurred!''; ' +                #13#10 +
      '      ELSE ' +                                                   #13#10 +
      '        S = S || '' Something bad happened!''; ' +               #13#10 +
      '      SUSPEND; --exception ex_custom S; ' +                      #13#10 +
      '    END ' +                                                      #13#10 +
      '  END ' +                                                        #13#10 +
      'END';        }


      'EXECUTE BLOCK ' +                                                                             #13#10 +
      'AS ' +                                                                                        #13#10 +
      '  DECLARE VARIABLE S VARCHAR(16384); ' +                                                      #13#10 +
      'BEGIN ' +                                                                                     #13#10 +
      '  FOR ' +                                                                                     #13#10 +
      '    SELECT ' +                                                                                #13#10 +
      '      ''ALTER TABLE '' || c.relation_name || ' +                                              #13#10 +
      '      '' ADD CONSTRAINT '' || c.constraint_name || '' '' || ' +                               #13#10 +
      '      c.constraint_type || '' ('' || ' +                                                      #13#10 +
      '      c.list_fields || '') '' ' +                                                             #13#10 +
      '    FROM dbs_pk_unique_constraints c ' +                                                      #13#10 +
  /// '      JOIN DBS_TMP_PROCESSED_TABLES p ON p.relation_name = c.RELATION_NAME ' +                #13#10 +
      '    WHERE ' +                                                                                 #13#10 +
      '      c.relation_name NOT LIKE ''DBS_%'' ' +                   			             #13#10 +
      ////////////////////                                                                                          
   {   '      AND NOT EXISTS( ' +                                                        	     #13#10 +
      '        SELECT * ' + 									     #13#10 +
      '        FROM dbs_fk_constraints cc ' +							     #13#10 +
      '        WHERE ' +									     #13#10 +
      '          cc.ref_relation_name = c.relation_name ' +					     #13#10 +
      '          AND cc.delete_rule IN(''SET NULL'', ''SET DEFAULT'') ' +                            #13#10 +
      '          AND cc.constraint_name NOT LIKE ''RDB$%'' ' +               			     #13#10 +
      '      ) ' +      }                                                                             #13#10 +
      ///////////////////
      '    INTO :S ' +                                                  			     #13#10 +
      '  DO BEGIN ' +                                                   			     #13#10 +
      '    EXECUTE STATEMENT :S; ' +                                    			     #13#10 +  /// WITH AUTONOMOUS TRANSACTION
      '    when any DO ' +                                              			     #13#10 +
      '    BEGIN ' +                                                    			     #13#10 +
      '      IF (sqlcode <> 0) THEN ' +                                 			     #13#10 +
      '        S = S || '' An SQL error occurred!''; ' +                			     #13#10 +
      '      ELSE ' +                                                   			     #13#10 +
      '        S = S || '' Something bad happened!''; ' +               			     #13#10 +
      '      SUSPEND; --exception ex_custom S; ' +                      			     #13#10 +
      '    END ' +                                                      			     #13#10 +
      '  END ' +                                                        			     #13#10 +
      'END';
    ExecSqlLogEvent(q, 'RestorePkUniqueConstraints');

    Tr.Commit;
    Tr.StartTransaction;

    LogEvent('PKs&UNIQs restored.');
  end;


  procedure RestoreFKConstraints;
  begin
    q.SQL.Text :=
      'EXECUTE BLOCK ' +                                                                            #13#10 +
      '  RETURNS(S VARCHAR(16384)) ' +                                                              #13#10 +
      'AS ' +                                                                                       #13#10 +
      'BEGIN ' +                                                                                    #13#10 +
      '  FOR ' +                                                                                    #13#10 +
      '    SELECT ' +                                                                               #13#10 +
      '      '' ALTER TABLE '' || c.relation_name || ' +                                            #13#10 +
      '      '' ADD CONSTRAINT '' || c.constraint_name || ' +                                       #13#10 +
      '      '' FOREIGN KEY ('' || c.list_fields || '') ' +                                         #13#10 +
      '         REFERENCES '' || c.ref_relation_name || ''('' || c.list_ref_fields || '') '' || ' + #13#10 +
      '      IIF(c.update_rule = ''RESTRICT'', '''', '' ON UPDATE '' || c.update_rule) || ' +       #13#10 +
      '      IIF(c.delete_rule = ''RESTRICT'', '''', '' ON DELETE '' || c.delete_rule) ' +          #13#10 +
      '    FROM ' +                                                                                 #13#10 +
      '      dbs_fk_constraints c ' +                                                               #13#10 +
     /// '      JOIN DBS_TMP_PROCESSED_TABLES p ON p.relation_name = c.RELATION_NAME ' +  #13#10 +
      '    WHERE ' +                                                                                #13#10 +
      '      c.constraint_name NOT LIKE ''DBS_%'' ' +                                               #13#10 +
      ////////////////////
    //   '      AND c.delete_rule NOT IN(''SET NULL'', ''SET DEFAULT'') ' +                            #13#10 +
      ///////////////////
      '      AND NOT EXISTS( ' +                                                                    #13#10 +
      '        SELECT tmp.constraint_name ' +                                                       #13#10 +
      '        FROM dbs_tmp_fk_constraints tmp ' +                                                  #13#10 +
      '        WHERE tmp.constraint_name = c.constraint_name ' +                                    #13#10 +
      '      )' +                                                                                 #13#10 +
      '    INTO :S ' +                                                                              #13#10 +
      '  DO BEGIN ' +                                                                               #13#10 +
      '    EXECUTE STATEMENT :S; ' +                                                                #13#10 +  /// WITH AUTONOMOUS TRANSACTION
      '    when any DO ' +                                                                          #13#10 +
      '    BEGIN ' +                                                                                #13#10 +
      '      IF (sqlcode <> 0) THEN ' +                                                             #13#10 +
      '        S = S || '' An SQL error occurred!''; ' +                                            #13#10 +
      '      ELSE ' +                                                                               #13#10 +
      '        S = S || '' Something bad happened!''; ' +                                           #13#10 +
      '      SUSPEND; --exception ex_custom S; ' +                                                  #13#10 +
      '    END ' +                                                                                  #13#10 +
      '  END ' +                                                                                    #13#10 +
      'END';
    ExecSqlLogEvent(q, 'RestoreFKConstraints');

    Tr.Commit;
    Tr.StartTransaction;

    LogEvent('FKs restored.');
  end;

begin
  LogEvent('Restoring DB...');
  Assert(Connected);

  Tr := TIBTransaction.Create(nil);
  q := TIBSQL.Create(nil);
  try
    Tr.DefaultDatabase := FIBDatabase;
    Tr.StartTransaction;

    q.Transaction := Tr;
    try
      RestoreIndices;                 //4%
      ProgressMsgEvent('', 4*PROGRESS_STEP);
      RestorePkUniqueConstraints;     //8%
      ProgressMsgEvent('', 8*PROGRESS_STEP);
      RestoreFKConstraints;           //16%
      ProgressMsgEvent('', 16*PROGRESS_STEP);
      RestoreTriggers;                //2%
      ProgressMsgEvent('', 2*PROGRESS_STEP);

      Tr.Commit;

    except
      on E: Exception do
      begin
        //Tr.Rollback;
        raise;
      end;
    end;
    LogEvent('Restoring DB... OK');
  finally
    q.Free;
    Tr.Free;
  end;
end;

procedure TgsDBSqueeze.SetItemsCbbEvent;
var
  Tr: TIBTransaction;
  q: TIBSQL;
  CompaniesList: TStringList;  // ������ ��������, �� ������� ������� ����
begin
  Assert(Connected and Assigned(FOnSetItemsCbbEvent));

  CompaniesList := TStringList.Create;
  Tr := TIBTransaction.Create(nil);
  q := TIBSQL.Create(nil);

  try
    Tr.DefaultDatabase := FIBDatabase;
    Tr.StartTransaction;

    q.Transaction := Tr;
    q.SQL.Text :=
      'SELECT ' +                                                       #13#10 +
      '  TRIM(go.companykey || ''='' || gc.fullname) AS CompName ' +    #13#10 +
      'FROM gd_ourcompany go ' +                                        #13#10 +
      '  JOIN GD_COMPANY gc ' +                                         #13#10 +
      '    ON go.companykey = gc.contactkey ';
    ExecSqlLogEvent(q, 'SetItemsCbbEvent');
    while not q.EOF do
    begin
      CompaniesList.Add(q.FieldByName('CompName').AsString);
      q.Next;
    end;

    FOnSetItemsCbbEvent(CompaniesList);
    q.Close;
    Tr.Commit;
  finally
    q.Free;
    Tr.Free;
    CompaniesList.Free;
  end;
end;

procedure TgsDBSqueeze.SetDocTypeStringsEvent;
var
  Tr: TIBTransaction;
  q: TIBSQL;
  DocTypeList: TStringList;  // ������ ����� ����������
begin
  Assert(FIBDatabase.Connected and Assigned(FOnSetDocTypeStringsEvent));

  DocTypeList := TStringList.Create;

  Tr := TIBTransaction.Create(nil);
  q := TIBSQL.Create(nil);

  try
    Tr.DefaultDatabase := FIBDatabase;
    Tr.StartTransaction;

    q.Transaction := Tr;
    q.SQL.Text :=
      'SELECT ' +                                                #13#10 +
      '  (TRIM(dt.id) || ''='' || TRIM(dt.name)) AS DocType ' +  #13#10 +
      'FROM GD_DOCUMENTTYPE dt ' +                               #13#10 +
      'ORDER BY dt.name';
    ExecSqlLogEvent(q, 'SetDocTypeStringsEvent');
    while not q.EOF do
    begin
      DocTypeList.Append(q.FieldByName('DocType').AsString);
      q.Next;
    end;

    FOnSetDocTypeStringsEvent(DocTypeList);
    q.Close;
    Tr.Commit;
  finally
    q.Free;
    Tr.Free;
    DocTypeList.Free;
  end;
end;

procedure TgsDBSqueeze.ExecSqlLogEvent(const AnIBSQL: TIBSQL; const AProcName: String);
const
  Ms = 1 / (24 * 60 * 60 * 1000); // �������� 1 ������������ � ������� TDateTime
var
  I: Integer;
  ParamValuesStr: String;
  StartDT: TDateTime;
  Start, Stop: Extended;
  Time : TDateTime;
  TimeStr: String;
  Hour, Min, Sec, Milli: Word;
begin
  ParamValuesStr := '';
  for I:=0 to AnIBSQL.Params.Count-1 do
  begin
    if I <> 0 then
     ParamValuesStr := ParamValuesStr + ', ';

    if AnIBSQL.Params.Vars[I].IsNull then
      ParamValuesStr := ParamValuesStr + AnIBSQL.Params.Vars[I].Name + '=NULL'
    else
      ParamValuesStr := ParamValuesStr + AnIBSQL.Params.Vars[I].Name + '=' + AnIBSQL.Params.Vars[I].AsString;
  end;

  TimeStr := '';
  FOnLogSQLEvent('Procedure: ' + AProcName);
  FOnLogSQLEvent(AnIBSQL.SQL.Text);
  if ParamValuesStr <> '' then
    FOnLogSQLEvent('Parameters: ' + ParamValuesStr);

  StartDT := Now;
  FOnLogSQLEvent('Begin Time: ' + FormatDateTime('h:nn:ss:zzz', StartDT));
  Start := GetTickCount;
  try
    AnIBSQL.ExecQuery;
  except
    on E: Exception do
    begin
      LogEvent('ERROR in procedure: ' + AProcName);
      LogEvent('ERROR SQL: ' + AnIBSQL.SQL.Text);
      if ParamValuesStr <> '' then
        LogEvent('Parameters: ' + ParamValuesStr);
      raise EgsDBSqueeze.Create(E.Message);
    end;
  end;
  Stop := GetTickCount;

  if AnIBSQL.RowsAffected <> -1 then
    FOnLogSQLEvent('Rows Affected: ' + IntToStr(AnIBSQL.RowsAffected))
  else
    FOnLogSQLEvent('Records Count: ' + IntToStr(AnIBSQL.RecordCount));

  Time := (Stop - Start) * Ms;
  DecodeTime(Time, Hour, Min, Sec, Milli);
  if Hour > 0 then
  begin
    TimeStr := TimeStr + IntToStr(Hour);
    if Hour > 1 then
      TimeStr := TimeStr + ' hours '
    else
      TimeStr := TimeStr + ' hour ';
  end;
  if Min > 0 then
  begin
    TimeStr := TimeStr + IntToStr(Min);
    if Min > 1 then
      TimeStr := TimeStr + ' minutes '
    else
      TimeStr := TimeStr + ' minute ';
  end;
  if Sec > 0 then
  begin
    TimeStr := TimeStr + IntToStr(Sec);
    if Sec > 1 then
      TimeStr := TimeStr + ' seconds '
    else
      TimeStr := TimeStr + ' second ';
  end;
  if Ms > 0 then
    TimeStr := TimeStr + IntToStr(Milli) + ' ms ';

  FOnLogSQLEvent('Execution Time: ' + TimeStr);
  FOnLogSQLEvent('End Time: ' + FormatDateTime('h:nn:ss:zzz', (StartDT + Time)));  ///TODO: ��� �� ���������� � � ����� �������
  FOnLogSQLEvent('   ');
end;

procedure TgsDBSqueeze.ExecSqlLogEvent(const AnIBQuery: TIBQuery; const AProcName: String);
const
  Ms = 1 / (24 * 60 * 60 * 1000); // �������� 1 ������������ � ������� TDateTime
var
  I: Integer;
  ParamValuesStr: String;
  StartDT: TDateTime;
  Start, Stop: Extended;
  Time : TDateTime;
  TimeStr: String;
  Hour, Min, Sec, Milli: Word;
begin
  ParamValuesStr := '';
  for I:=0 to AnIBQuery.Params.Count-1 do
  begin
    if I <> 0 then
     ParamValuesStr := ParamValuesStr + ', ';

    if AnIBQuery.Params[I].IsNull then
      ParamValuesStr := ParamValuesStr + AnIBQuery.Params[I].Name + '=NULL'
    else
      ParamValuesStr := ParamValuesStr + AnIBQuery.Params[I].Name + '=' + AnIBQuery.Params[I].AsString;
  end;

  TimeStr := '';
  FOnLogSQLEvent('Procedure: ' + AProcName);
  FOnLogSQLEvent(AnIBQuery.SQL.Text);
  if ParamValuesStr <> '' then
    FOnLogSQLEvent('Parameters: ' + ParamValuesStr);

  StartDT := Now;
  FOnLogSQLEvent('Begin Time: ' + FormatDateTime('h:nn:ss:zzz', StartDT));
  Start := GetTickCount;
  try
    AnIBQuery.Open;
  except
    on E: Exception do
    begin
      LogEvent('ERROR in procedure: ' + AProcName);
      LogEvent('ERROR SQL: ' + AnIBQuery.SQL.Text);
      if ParamValuesStr <> '' then
        LogEvent('Parameters: ' + ParamValuesStr);
      raise EgsDBSqueeze.Create(E.Message);
    end;
  end;
  Stop := GetTickCount;

  if AnIBQuery.RowsAffected <> -1 then
    FOnLogSQLEvent('Rows Affected: ' + IntToStr(AnIBQuery.RowsAffected))
  else
    FOnLogSQLEvent('Records Count: ' + IntToStr(AnIBQuery.RecordCount));

  Time := (Stop - Start) * Ms;
  DecodeTime(Time, Hour, Min, Sec, Milli);
  if Hour > 0 then
  begin
    TimeStr := TimeStr + IntToStr(Hour);
    if Hour > 1 then
      TimeStr := TimeStr + ' hours '
    else
      TimeStr := TimeStr + ' hour ';
  end;
  if Min > 0 then
  begin
    TimeStr := TimeStr + IntToStr(Min);
    if Min > 1 then
      TimeStr := TimeStr + ' minutes '
    else
      TimeStr := TimeStr + ' minute ';
  end;
  if Sec > 0 then
  begin
    TimeStr := TimeStr + IntToStr(Sec);
    if Sec > 1 then
      TimeStr := TimeStr + ' seconds '
    else
      TimeStr := TimeStr + ' second ';
  end;
  if Ms > 0 then
    TimeStr := TimeStr + IntToStr(Milli) + ' ms ';

  FOnLogSQLEvent('Execution Time: ' + TimeStr);
  FOnLogSQLEvent('End Time: ' + FormatDateTime('h:nn:ss:zzz', (StartDT + Time)));  ///TODO: ��� �� ���������� � � ����� �������
  FOnLogSQLEvent('   ');
end;

procedure TgsDBSqueeze.FuncTest(const AFuncName: String; const ATr: TIBTransaction);
var
  q: TIBSQL;
begin
  q := TIBSQL.Create(nil);
  try
    q.Transaction := ATr;

    q.SQL.Text := 'SELECT ' + AFuncName;

    if AnsiUpperCase(Trim(AFuncName)) = 'G_HIS_CREATE' then
      q.SQL.Add('(0, 0)')
    else if (AnsiUpperCase(Trim(AFuncName)) = 'G_HIS_INCLUDE') or
      (AnsiUpperCase(Trim(AFuncName)) = 'G_HIS_EXCLUDE') or
      (AnsiUpperCase(Trim(AFuncName)) = 'G_HIS_HAS') then
       q.SQL.Add('(0, 1)')
    else if (AnsiUpperCase(Trim(AFuncName)) = 'G_HIS_DESTROY') or
      (AnsiUpperCase(Trim(AFuncName)) = 'G_HIS_COUNT') then
      q.SQL.Add('(0)');

    q.SQL.Add(' FROM rdb$database');

    try
      ExecSqlLogEvent(q, 'FuncTest');
    except
      on E: Exception do
      begin
        raise EgsDBSqueeze.Create('Error: function ' + AFuncName + ' unknown in UDF library. ' + E.Message);
      end;
    end;
  finally
    q.Free;
  end;
end;

procedure TgsDBSqueeze.CreateMetadata;
var
  q: TIBSQL;
  q2: TIBSQL;
  Tr: TIBTransaction;

  procedure CreateDBSTmpProcessedTbls;
  begin
    if RelationExist2('DBS_TMP_PROCESSED_TABLES', Tr) then
    begin
      q.SQL.Text := 'DELETE FROM dbs_tmp_processed_tables';
      ExecSqlLogEvent(q, 'CreateDBSTmpProcessedTbls');
      LogEvent('Table DBS_TMP_PROCESSED_TABLES exists.');
    end
    else begin
      q.SQL.Text :=
        'CREATE TABLE DBS_TMP_PROCESSED_TABLES ( ' +    #13#10 +
        '  RELATION_NAME VARCHAR(31), ' +               #13#10 +
        '  constraint PK_DBS_TMP_PROCESSED_TABLES primary key (RELATION_NAME))';
      ExecSqlLogEvent(q, 'CreateDBSTmpProcessedTbls');
      LogEvent('Table DBS_TMP_PROCESSED_TABLES has been created.');
    end;
  end;

  procedure CreateDBSTmpRebindInvCards;
  begin
    if RelationExist2('DBS_TMP_REBIND_INV_CARDS', Tr) then
    begin
      q.SQL.Text := 'DELETE FROM dbs_tmp_rebind_inv_cards';
      ExecSqlLogEvent(q, 'CreateDBSTmpRebindInvCards');
      LogEvent('Table DBS_TMP_REBIND_INV_CARDS exists.');
    end
    else begin
      q.SQL.Text :=
        'CREATE TABLE DBS_TMP_REBIND_INV_CARDS ( ' +    #13#10 +
        '  CUR_CARDKEY       INTEGER, ' +               #13#10 +
        '  NEW_CARDKEY       INTEGER, ' +               #13#10 +
        '  CUR_FIRST_DOCKEY  INTEGER, ' +               #13#10 +
        '  FIRST_DOCKEY      INTEGER, ' +               #13#10 +
        '  FIRST_DATE        DATE, ' +                  #13#10 +
        '  CUR_RELATION_NAME VARCHAR(31)) ';
      ExecSqlLogEvent(q, 'CreateDBSTmpRebindInvCards');
      LogEvent('Table DBS_TMP_REBIND_INV_CARDS has been created.');
    end;
  end;

  procedure CreateDBSTmpAcSaldo;
  begin
    if RelationExist2('DBS_TMP_AC_SALDO', Tr) then
    begin
      q.SQL.Text := 'DELETE FROM dbs_tmp_ac_saldo';
      ExecSqlLogEvent(q, 'CreateDBSTmpAcSaldo');
      LogEvent('Table DBS_TMP_AC_SALDO exists.');
    end
    else begin
      q2.SQL.Text :=
        'SELECT LIST( ' +                                               #13#10 +
        '  TRIM(rf.rdb$field_name) || '' '' || ' +                      #13#10 +
        '  CASE f.rdb$field_type ' +                                    #13#10 +
        '    WHEN 7 THEN ' +                                            #13#10 +
        '      CASE f.rdb$field_sub_type ' +                            #13#10 +
        '        WHEN 0 THEN '' SMALLINT'' ' +                          #13#10 +
        '        WHEN 1 THEN '' NUMERIC('' || f.rdb$field_precision || '','' || (-f.rdb$field_scale) || '')'' ' +  #13#10 +
        '        WHEN 2 THEN '' DECIMAL(''  || f.rdb$field_precision || '','' || (-f.rdb$field_scale) || '')'' ' + #13#10 +
        '      END ' +                                                  #13#10 +
        '    WHEN 8 THEN ' +                                            #13#10 +
        '      CASE f.rdb$field_sub_type ' +                            #13#10 +
        '        WHEN 0 THEN '' INTEGER'' ' +                           #13#10 +
        '        WHEN 1 THEN '' NUMERIC(''  || f.rdb$field_precision || '','' || (-f.rdb$field_scale) || '')'' ' + #13#10 +
        '        WHEN 2 THEN '' DECIMAL(''  || f.rdb$field_precision || '','' || (-f.rdb$field_scale) || '')'' ' + #13#10 +
        '      END ' +                                                  #13#10 +
        '    WHEN 9 THEN '' QUAD'' ' +                                  #13#10 +
        '    WHEN 10 THEN '' FLOAT'' ' +                                #13#10 +
        '    WHEN 12 THEN '' DATE'' ' +                                 #13#10 +
        '    WHEN 13 THEN '' TIME'' ' +                                 #13#10 +
        '    WHEN 14 THEN '' CHAR('' || (TRUNC(f.rdb$field_length / ch.rdb$bytes_per_character)) || '')'' ' +      #13#10 +
        '    WHEN 16 THEN ' +                                           #13#10 +
        '      CASE f.rdb$field_sub_type ' +                            #13#10 +
        '        WHEN 0 THEN '' BIGINT'' ' +                            #13#10 +
        '        WHEN 1 THEN '' NUMERIC(''  || f.rdb$field_precision || '','' || (-f.rdb$field_scale) || '')'' ' + #13#10 +
        '        WHEN 2 THEN '' DECIMAL(''  || f.rdb$field_precision || '','' || (-f.rdb$field_scale) || '')'' ' + #13#10 +
        '      END ' +                                                  #13#10 +
        '    WHEN 27 THEN '' DOUBLE'' ' +                               #13#10 +
        '    WHEN 35 THEN '' TIMESTAMP'' ' +                            #13#10 +
        '    WHEN 37 THEN '' VARCHAR('' || (TRUNC(f.rdb$field_length / ch.rdb$bytes_per_character)) || '')'' ' +   #13#10 +
        '    WHEN 40 THEN '' CSTRING('' || (TRUNC(f.rdb$field_length / ch.rdb$bytes_per_character)) || '')'' ' +   #13#10 +
        '    WHEN 45 THEN '' BLOB_ID'' ' +                              #13#10 +
        '    WHEN 261 THEN '' BLOB'' ' +                                #13#10 +
        '    ELSE '' RDB$FIELD_TYPE:?'' ' +                             #13#10 +
        '  END)  AS AllUsrFieldsList ' +                                #13#10 +
        'FROM rdb$relation_fields rf ' +                                #13#10 +
        '  JOIN rdb$fields f ON (f.rdb$field_name = rf.rdb$field_source) ' +                                       #13#10 +
        '  LEFT OUTER JOIN rdb$character_sets ch ON (ch.rdb$character_set_id = f.rdb$character_set_id) ' +         #13#10 +
        'WHERE ' +                                                      #13#10 +
        '  rf.rdb$relation_name = ''AC_ENTRY'' ' +                      #13#10 +
        '  AND rf.rdb$field_name LIKE ''USR$%'' ' +                     #13#10 +
        '  AND COALESCE(rf.rdb$system_flag, 0) = 0 ';
      ExecSqlLogEvent(q2, 'CreateDBSTmpAcSaldo');

      q.SQL.Text :=
        'CREATE TABLE DBS_TMP_AC_SALDO ( ' +            #13#10 +
        '  ID           INTEGER, ' +                    #13#10 +
        '  ID_OSTATKY   INTEGER, ' +                    #13#10 +
        '  COMPANYKEY   INTEGER, ' +                    #13#10 +
        '  CURRKEY      INTEGER, ' +                    #13#10 +
        '  ACCOUNTKEY   INTEGER, ' +                    #13#10 +
        '  MASTERDOCKEY INTEGER, ' +                    #13#10 +
        '  DOCUMENTKEY  INTEGER, ' +                    #13#10 +
        '  RECORDKEY    INTEGER, ' +                    #13#10 +
        '  RECORDKEY_OSTATKY INTEGER, ' +               #13#10 +
        '  ACCOUNTPART  VARCHAR(1), ' +                 #13#10 +
        '  CREDITNCU    DECIMAL(15,4), ' +              #13#10 +
        '  CREDITCURR   DECIMAL(15,4), ' +              #13#10 +
        '  CREDITEQ     DECIMAL(15,4), ' +              #13#10 +
        '  DEBITNCU     DECIMAL(15,4), ' +              #13#10 +
        '  DEBITCURR    DECIMAL(15,4), ' +              #13#10 +
        '  DEBITEQ      DECIMAL(15,4), ';
      if q2.RecordCount <> 0 then
        q.SQL.Add(' ' +
          q2.FieldByName('AllUsrFieldsList').AsString + ', ');
      q.SQL.Add(' ' +
        '  constraint PK_DBS_TMP_AC_SALDO primary key (ID))');
      ExecSqlLogEvent(q, 'CreateDBSTmpAcSaldo');

      q2.Close;
      LogEvent('Table DBS_TMP_AC_SALDO has been created.');
    end;
  end;

  procedure CreateDBSTmpInvSaldo;
  begin
    if RelationExist2('DBS_TMP_INV_SALDO', Tr) then
    begin
      q.SQL.Text := 'DELETE FROM dbs_tmp_inv_saldo';
      ExecSqlLogEvent(q, 'CreateDBSTmpInvSaldo');
      LogEvent('Table DBS_TMP_INV_SALDO exists.');
    end
    else begin
     { q2.SQL.Text :=
        'SELECT LIST( ' +
        '  TRIM(rf.rdb$field_name) || '' '' || ' +
        '  CASE f.rdb$field_type ' +
        '    WHEN 7 THEN ' +
        '      CASE f.rdb$field_sub_type ' +
        '        WHEN 0 THEN '' SMALLINT'' ' +
        '        WHEN 1 THEN '' NUMERIC('' || f.rdb$field_precision || '','' || (-f.rdb$field_scale) || '')'' ' +
        '        WHEN 2 THEN '' DECIMAL(''  || f.rdb$field_precision || '','' || (-f.rdb$field_scale) || '')'' ' +
        '      END ' +
        '    WHEN 8 THEN ' +
        '      CASE f.rdb$field_sub_type ' +
        '        WHEN 0 THEN '' INTEGER'' ' +
        '        WHEN 1 THEN '' NUMERIC(''  || f.rdb$field_precision || '','' || (-f.rdb$field_scale) || '')'' ' +
        '        WHEN 2 THEN '' DECIMAL(''  || f.rdb$field_precision || '','' || (-f.rdb$field_scale) || '')'' ' +
        '      END ' +
        '    WHEN 9 THEN '' QUAD'' ' +
        '    WHEN 10 THEN '' FLOAT'' ' +
        '    WHEN 12 THEN '' DATE'' ' +
        '    WHEN 13 THEN '' TIME'' ' +
        '    WHEN 14 THEN '' CHAR('' || (TRUNC(f.rdb$field_length / ch.rdb$bytes_per_character)) || '')'' ' +
        '    WHEN 16 THEN ' +
        '      CASE f.rdb$field_sub_type ' +
        '        WHEN 0 THEN '' BIGINT'' ' +
        '        WHEN 1 THEN '' NUMERIC(''  || f.rdb$field_precision || '','' || (-f.rdb$field_scale) || '')'' ' +
        '        WHEN 2 THEN '' DECIMAL(''  || f.rdb$field_precision || '','' || (-f.rdb$field_scale) || '')'' ' +
        '      END ' +
        '    WHEN 27 THEN '' DOUBLE'' ' +
        '    WHEN 35 THEN '' TIMESTAMP'' ' +
        '    WHEN 37 THEN '' VARCHAR('' || (TRUNC(f.rdb$field_length / ch.rdb$bytes_per_character)) || '')'' ' +
        '    WHEN 40 THEN '' CSTRING('' || (TRUNC(f.rdb$field_length / ch.rdb$bytes_per_character)) || '')'' ' +
        '    WHEN 45 THEN '' BLOB_ID'' ' +
        '    WHEN 261 THEN '' BLOB'' ' +
        '    ELSE '' RDB$FIELD_TYPE:?'' ' +
        '  END)  AS AllUsrFieldsList ' +
        'FROM rdb$relation_fields rf ' +
        '  JOIN rdb$fields f ON (f.rdb$field_name = rf.rdb$field_source) ' +
        '  LEFT OUTER JOIN rdb$character_sets ch ON (ch.rdb$character_set_id = f.rdb$character_set_id) ' +
        'WHERE ' +
        '  rf.rdb$relation_name = ''INV_CARD'' ' +
        '  AND rf.rdb$field_name LIKE ''USR$%'' ' +
        '  AND COALESCE(rf.rdb$system_flag, 0) = 0 ';
      ExecSqlLogEvent(q2, 'CreateDBSTmpInvSaldo'); }

      q.SQL.Text :=
        'CREATE TABLE DBS_TMP_INV_SALDO ( ' +           #13#10 +
        //'  ID_DOCUMENT   INTEGER, ' +                   #13#10 +
        //'  ID_PARENTDOC  INTEGER, ' +                   #13#10 +
        //'  ID_CARD       INTEGER, ' +                   #13#10 +
        '  ID_MOVEMENT_D INTEGER, ' +                   #13#10 +
        '  ID_MOVEMENT_C INTEGER, ' +                   #13#10 +
        '  MOVEMENTKEY   INTEGER, ' +                   #13#10 +
        '  CONTACTKEY    INTEGER, ' +                   #13#10 +
        '  GOODKEY       INTEGER, ' +                   #13#10 +
        '  CARDKEY       INTEGER, ' +                   #13#10 +
        '  COMPANYKEY    INTEGER, ' +                   #13#10 +
        '  BALANCE       DECIMAL(15,4), ';
     { if q2.RecordCount <> 0 then
        q.SQL.Add(' ' +
           q2.FieldByName('AllUsrFieldsList').AsString + ', ');       }
      q.SQL.Add(' ' +
        '  constraint PK_DBS_TMP_INV_SALDO primary key (MOVEMENTKEY))');
      ExecSqlLogEvent(q, 'CreateDBSTmpInvSaldo');

      //q2.Close;
      LogEvent('Table DBS_TMP_INV_SALDO has been created.');
    end;
  end;

  procedure CreateDBSTmpInvCard;
  begin
    if RelationExist2('DBS_TMP_INV_CARD', Tr) then
    begin
      q.SQL.Text := 'DELETE FROM dbs_tmp_inv_card';
      ExecSqlLogEvent(q, 'CreateDBSTmpInvCard');
      LogEvent('Table DBS_TMP_INV_CARD exists.');
    end
    else begin
      q.SQL.Text :=
        'CREATE TABLE DBS_TMP_INV_CARD ( ' +  #13#10 +
        '  ID_CARD           INTEGER, ' +     #13#10 +
        '  NEW_CARD          INTEGER, ' +     #13#10 +
        '  GOODKEY           INTEGER, ' +     #13#10 +
        '  COMPANYKEY        INTEGER, ' +     #13#10 +
        '  DOCUMENTKEY       INTEGER, ' +     #13#10 +
        '  FIRSTDOCUMENTKEY  INTEGER, ';
      q.SQL.Add(' ' +
        '  constraint PK_DBS_TMP_INV_CARD primary key (ID_CARD))');
      ExecSqlLogEvent(q, 'CreateDBSTmpInvSaldo');

      LogEvent('Table DBS_TMP_INV_CARD has been created.');
    end;
  end;

  procedure CreateDBSInactiveTriggers;
  begin
    if RelationExist2('DBS_INACTIVE_TRIGGERS', Tr) then
    begin
      q.SQL.Text := 'DELETE FROM dbs_inactive_triggers';
      ExecSqlLogEvent(q, 'CreateDBSInactiveTriggers');
      LogEvent('Table DBS_INACTIVE_TRIGGERS exists.');
    end
    else begin
      q.SQL.Text :=
        'CREATE TABLE DBS_INACTIVE_TRIGGERS ( ' +       #13#10 +
        '  TRIGGER_NAME  CHAR(31) NOT NULL, ' +         #13#10 +
        '  constraint PK_DBS_INACTIVE_TRIGGERS primary key (TRIGGER_NAME))';
      ExecSqlLogEvent(q, 'CreateDBSInactiveTriggers');
      LogEvent('Table DBS_INACTIVE_TRIGGERS has been created.');
    end;
  end;
    
  procedure CreateDBSInactiveIndices;
  begin
    if RelationExist2('DBS_INACTIVE_INDICES', Tr) then
    begin
      q.SQL.Text := 'DELETE FROM dbs_inactive_indices';
      ExecSqlLogEvent(q, 'CreateDBSInactiveIndices');
      LogEvent('Table DBS_INACTIVE_INDICES exists.');
    end
    else begin
      q.SQL.Text :=
        'CREATE TABLE DBS_INACTIVE_INDICES ( ' +        #13#10 +
        '  INDEX_NAME   CHAR(31) NOT NULL, ' +          #13#10 +
        '  constraint PK_DBS_INACTIVE_INDICES primary key (INDEX_NAME))';
      ExecSqlLogEvent(q, 'CreateDBSInactiveIndices');
      LogEvent('Table DBS_INACTIVE_INDICES has been created.');
    end;
  end;

  procedure CreateDBSPkUniqueConstraints;
  begin
    if RelationExist2('DBS_PK_UNIQUE_CONSTRAINTS', Tr) then
    begin
      q.SQL.Text := 'DELETE FROM dbs_pk_unique_constraints';
      ExecSqlLogEvent(q, 'CreateDBSPkUniqueConstraints');
      LogEvent('Table DBS_PK_UNIQUE_CONSTRAINTS exist.');
    end
    else begin
      q.SQL.Text :=
        'CREATE TABLE DBS_PK_UNIQUE_CONSTRAINTS ( ' +   #13#10 +
	'  CONSTRAINT_NAME   CHAR(35), ' +              #13#10 +
	'  RELATION_NAME     CHAR(31), ' +              #13#10 +
	'  CONSTRAINT_TYPE   CHAR(11), ' +              #13#10 +
	'  LIST_FIELDS       VARCHAR(310), ' +          #13#10 +
	'  constraint PK_DBS_PK_UNIQUE_CONSTRAINTS primary key (CONSTRAINT_NAME)) ';
      ExecSqlLogEvent(q, 'CreateDBSPkUniqueConstraints');
      q.Close;
      LogEvent('Table DBS_PK_UNIQUE_CONSTRAINTS has been created.');
    end;
  end;

  procedure CreateDBSSuitableTables;
  begin
    if RelationExist2('DBS_SUITABLE_TABLES', Tr) then
    begin
      q.SQL.Text := 'DELETE FROM dbs_suitable_tables';
      ExecSqlLogEvent(q, 'CreateDBSSuitableTables');
      LogEvent('Table DBS_SUITABLE_TABLES exist.');
    end
    else begin
      q.SQL.Text :=
        'CREATE TABLE DBS_SUITABLE_TABLES ( ' +         #13#10 +
	'  RELATION_NAME     CHAR(31), ' +              #13#10 +
	'  LIST_FIELDS       VARCHAR(310), ' +          #13#10 + // pk
	'  constraint PK_DBS_SUITABLE_TABLES primary key (RELATION_NAME)) ';
      ExecSqlLogEvent(q, 'CreateDBSSuitableTables');
      q.Close;
      LogEvent('Table DBS_SUITABLE_TABLES has been created.');
    end;
  end;

  procedure CreateDBSFKConstraints;
  begin
    if RelationExist2('DBS_FK_CONSTRAINTS', Tr) then
    begin
      q.SQL.Text := 'DELETE FROM dbs_fk_constraints';
      ExecSqlLogEvent(q, 'CreateDBSFKConstraints');
      LogEvent('Table DBS_FK_CONSTRAINTS exists.');
    end
    else begin
      q.SQL.Text :=
        'CREATE TABLE DBS_FK_CONSTRAINTS ( ' +          #13#10 +
        '  CONSTRAINT_NAME   CHAR(40), ' +              #13#10 +
        '  RELATION_NAME     CHAR(31), ' +              #13#10 +
        '  LIST_FIELDS       VARCHAR(8192), ' +         #13#10 +
        '  REF_RELATION_NAME CHAR(31), ' +              #13#10 +
        '  LIST_REF_FIELDS   VARCHAR(8192), ' +         #13#10 +
        '  UPDATE_RULE       CHAR(11), ' +              #13#10 +
        '  DELETE_RULE       CHAR(11), ' +              #13#10 +
        '  constraint PK_DBS_FK_CONSTRAINTS primary key (CONSTRAINT_NAME))';
      ExecSqlLogEvent(q, 'CreateDBSFKConstraints');
      LogEvent('Table DBS_FK_CONSTRAINTS has been created.');
    end;
  end;

  procedure CreateDBSTmpFKConstraints;
  begin
    if RelationExist2('DBS_TMP_FK_CONSTRAINTS', Tr) then
    begin
      q.SQL.Text := 'DELETE FROM dbs_tmp_fk_constraints';
      ExecSqlLogEvent(q, 'CreateDBSTmpFKConstraints');
      LogEvent('Table DBS_TMP_FK_CONSTRAINTS exists.');
    end
    else begin
      q.SQL.Text :=
        'CREATE TABLE DBS_TMP_FK_CONSTRAINTS ( ' +      #13#10 +
        '  CONSTRAINT_NAME   CHAR(40), ' +              #13#10 +
        '  RELATION_NAME     CHAR(31), ' +              #13#10 +
        '  LIST_FIELDS       VARCHAR(8192), ' +         #13#10 +
        '  REF_RELATION_NAME CHAR(31), ' +              #13#10 +
        '  LIST_REF_FIELDS   VARCHAR(8192), ' +         #13#10 +
        '  UPDATE_RULE       CHAR(11), ' +              #13#10 +
        '  DELETE_RULE       CHAR(11), ' +              #13#10 +
        '  constraint PK_DBS_TMP_FK_CONSTRAINTS primary key (CONSTRAINT_NAME))';
      ExecSqlLogEvent(q, 'CreateDBSTmpFKConstraints');
      LogEvent('Table DBS_TMP_FK_CONSTRAINTS has been created.');
    end;
  end;

 { procedure CreateDBSTmpPkHash;
  begin
    if RelationExist2('DBS_TMP_PK_HASH', Tr) then
    begin
      q.SQL.Text := 'DELETE FROM dbs_tmp_pk_hash';
      ExecSqlLogEvent(q, 'CreateDBSTmpPkHash');
      LogEvent('Table DBS_TMP_FK_CONSTRAINTS exists.');
    end
    else begin
      q.SQL.Text :=
        'CREATE TABLE DBS_TMP_PK_HASH ( ' +             #13#10 +
        '  PK            INTEGER  not null,  ' +        #13#10 +
        '  RELATION_NAME CHAR(31) not null, ' +         #13#10 +
        '  PK_HASH       BIGINT, ' +                    #13#10 +
        '  PK_FIELD      CHAR(31), ' +                  #13#10 +
        '  constraint PK_DBS_TMP_PK_HASH primary key (PK, RELATION_NAME) using index DBS_IX_DBS_TMP_PK_HASH) ';
      ExecSqlLogEvent(q, 'CreateDBSTmpPkHash');
      LogEvent('Table DBS_TMP_PK_HASH has been created.');
    end;
  end;}

  {procedure CreateDBSTmpHIS2;
  begin
    if RelationExist2('DBS_TMP_HIS_2', Tr) then
    begin
      q.SQL.Text := 'DELETE FROM DBS_TMP_HIS_2';
      ExecSqlLogEvent(q, 'CreateDBSTmpHIS2');
      LogEvent('Table DBS_TMP_HIS_2 exists.');
    end
    else begin
      q.SQL.Text :=
        'CREATE TABLE DBS_TMP_HIS_2 ( ' +               #13#10 +
        '  PK            INTEGER  not null,  ' +        #13#10 +
        '  RELATION_NAME CHAR(31) not null, ' +         #13#10 +
        '  PK_HASH       BIGINT, ' +                    #13#10 +
        '  PK_FIELD      CHAR(31), ' +                  #13#10 +
        '  constraint PK_DBS_TMP_HIS_2 primary key (PK, RELATION_NAME) using index DBS_IX_DBS_TMP_HIS_2) ';
      ExecSqlLogEvent(q, 'CreateDBSTmpHIS2');
      LogEvent('Table PK_DBS_TMP_HIS_2 has been created.');
    end;
  end; }

  procedure CreateUDFs;
  begin
    try
      if FunctionExist2('G_HIS_CREATE', Tr) then
      begin
        FuncTest('G_HIS_CREATE', Tr);
        LogEvent('Function g_his_create exists.');
      end
      else begin
        q.SQL.Text :=
          'DECLARE EXTERNAL FUNCTION G_HIS_CREATE ' +   #13#10 +
          '  INTEGER, ' +                               #13#10 +
          '  INTEGER ' +                                #13#10 +
          'RETURNS INTEGER BY VALUE ' +                 #13#10 +
          'ENTRY_POINT ''g_his_create'' MODULE_NAME ''gudf'' ';
        ExecSqlLogEvent(q, 'CreateUDFs');
        LogEvent('Function g_his_create has been declared.');
      end;

      if FunctionExist2('G_HIS_INCLUDE', Tr) then
      begin
        FuncTest('G_HIS_INCLUDE', Tr);
        LogEvent('Function g_his_include exists.');
      end
      else begin
        q.SQL.Text :=
          'DECLARE EXTERNAL FUNCTION G_HIS_INCLUDE ' +  #13#10 +
          ' INTEGER, ' +                                #13#10 +
          ' INTEGER ' +                                 #13#10 +
          'RETURNS INTEGER BY VALUE ' +                 #13#10 +
          'ENTRY_POINT ''g_his_include'' MODULE_NAME ''gudf'' ';
        ExecSqlLogEvent(q, 'CreateUDFs');
        LogEvent('Function g_his_include has been declared.');
      end;

      if FunctionExist2('G_HIS_HAS', Tr) then
      begin
        FuncTest('G_HIS_HAS', Tr);
        LogEvent('Function g_his_has exists.');
      end
      else begin
        q.SQL.Text :=
          'DECLARE EXTERNAL FUNCTION G_HIS_HAS ' +      #13#10 +
          ' INTEGER, ' +                                #13#10 +
          ' INTEGER  ' +                                #13#10 +
          'RETURNS INTEGER BY VALUE ' +                 #13#10 +
          'ENTRY_POINT ''g_his_has'' MODULE_NAME ''gudf'' ';
        ExecSqlLogEvent(q, 'CreateUDFs');
        LogEvent('Function g_his_has has been declared.');
      end;

      if FunctionExist2('G_HIS_COUNT', Tr) then
      begin
        FuncTest('G_HIS_COUNT', Tr);
        LogEvent('Function g_his_count exists.');
      end
      else begin
        q.SQL.Text :=
          'DECLARE EXTERNAL FUNCTION G_HIS_COUNT ' +    #13#10 +
          ' INTEGER ' +                                 #13#10 +
          'RETURNS INTEGER BY VALUE ' +                 #13#10 +
          'ENTRY_POINT ''g_his_count'' MODULE_NAME ''gudf'' ';
        ExecSqlLogEvent(q, 'CreateUDFs');
        LogEvent('Function g_his_count has been declared.');
      end;

      if FunctionExist2('G_HIS_EXCLUDE', Tr) then
      begin
        FuncTest('G_HIS_EXCLUDE', Tr);
        LogEvent('Function g_his_exclude exists.');
      end
      else begin
        q.SQL.Text :=
          'DECLARE EXTERNAL FUNCTION G_HIS_EXCLUDE ' +  #13#10 +
          '  INTEGER, ' +                               #13#10 +
          '  INTEGER ' +                                #13#10 +
          'RETURNS INTEGER BY VALUE ' +                 #13#10 +
          'ENTRY_POINT ''g_his_exclude'' MODULE_NAME ''gudf'' ';
        ExecSqlLogEvent(q, 'CreateUDFs');
        LogEvent('Function g_his_exclude has been declared.');
      end;

      if FunctionExist2('G_HIS_DESTROY', Tr) then
      begin
        FuncTest('G_HIS_DESTROY', Tr);
        LogEvent('Function g_his_destroy exists.');
      end
      else begin
        q.SQL.Text :=
          'DECLARE EXTERNAL FUNCTION G_HIS_DESTROY ' +  #13#10 +
          '  INTEGER ' +                                #13#10 +
          'RETURNS INTEGER BY VALUE ' +                 #13#10 +
          'ENTRY_POINT ''g_his_destroy'' MODULE_NAME ''gudf'' ';
        ExecSqlLogEvent(q, 'CreateUDFs');
        LogEvent('Function g_his_destroy has been declared.');
      end;

      {if FunctionExist2('bin_and', Tr) then
      begin
        q.SQL.Text :=
          'DECLARE EXTERNAL FUNCTION bin_and ' +
          ' INTEGER, ' +
          ' INTEGER ' +
          'RETURNS INTEGER BY VALUE ' +
          'ENTRY_POINT ''IB_UDF_bin_and'' MODULE_NAME ''ib_udf'' ';
        q.ExecQuery;
      end;

      if FunctionExist2('bin_or', Tr) then
      begin
        q.SQL.Text :=
          'DECLARE EXTERNAL FUNCTION bin_or ' +
          ' INTEGER, INTEGER ' +
          'RETURNS INTEGER BY VALUE ' +
          'ENTRY_POINT ''IB_UDF_bin_or'' MODULE_NAME ''ib_udf'' ';
        q.ExecQuery;
      end;  }
    except
      on E: Exception do
      begin
        Tr.Rollback;
        raise EgsDBSqueeze.Create(E.Message);
      end;
    end;
  end;

begin
  LogEvent('Creating metadata...');
  Assert(Connected);

  Tr := TIBTransaction.Create(nil);
  q := TIBSQL.Create(nil);
  q2 := TIBSQL.Create(nil);
  try
    Tr.DefaultDatabase := FIBDatabase;
    Tr.StartTransaction;

    q.Transaction := Tr;
    q2.Transaction := Tr;

    CreateDBSTmpProcessedTbls;
    CreateDBSTmpAcSaldo;
    CreateDBSTmpInvSaldo;
    CreateDBSTmpInvCard;
    CreateDBSTmpRebindInvCards;

    CreateDBSInactiveTriggers;
    CreateDBSInactiveIndices;
    CreateDBSPkUniqueConstraints;
    CreateDBSSuitableTables;
    CreateDBSFKConstraints;

    CreateDBSTmpFKConstraints;

    CreateUDFs;

    Tr.Commit;
    LogEvent('Creating metadata... OK');
  finally
    q.Free;
    q2.Free;
    Tr.Free;
  end;
end;

procedure TgsDBSqueeze.UsedDBEvent;
var
  q: TIBSQL;
  Tr: TIBTransaction;
begin
  Assert(Connected);

  Tr := TIBTransaction.Create(nil);
  q := TIBSQL.Create(nil);
  try
    Tr.DefaultDatabase := FIBDatabase;
    Tr.StartTransaction;
    q.Transaction := Tr;

    if RelationExist2('DBS_JOURNAL_STATE', Tr) then
    begin
      q.SQL.Text :=
        'SELECT FIRST(1) * ' +                          #13#10 +
        'FROM dbs_journal_state ' +                     #13#10 +
        'ORDER BY call_time DESC';
      ExecSqlLogEvent(q, 'UsedDBEvent');

      LogEvent('Warning: It''s USED DB! ');
      LogEvent('Latest operation: CALL_TIME=' + q.FieldByName('CALL_TIME').AsString +
        ', Message FUNCTIONKEY=WM_USER+' + IntToStr(q.FieldByName('FUNCTIONKEY').AsInteger - WM_USER) +
        ', SUCCESSFULLY=' + q.FieldByName('STATE').AsString);

      FOnUsedDBEvent(
        q.FieldByName('FUNCTIONKEY').AsInteger,
        q.FieldByName('STATE').AsInteger,
        q.FieldByName('CALL_TIME').AsString,
        q.FieldByName('ERROR_MESSAGE').AsString
      );

      q.Close;
    end;
    Tr.Commit;
  finally
    q.Free;
    Tr.Free;
  end;
end;

procedure TgsDBSqueeze.GetDBSizeEvent;                                          

  function BytesToStr(const i64Size: Int64): String;
  const
    i64GB = 1024 * 1024 * 1024;
    i64MB = 1024 * 1024;
    i64KB = 1024;
  begin
    if i64Size div i64GB > 0 then
      Result := Format('%.2f GB', [i64Size / i64GB])
    else if i64Size div i64MB > 0 then
      Result := Format('%.2f MB', [i64Size / i64MB])
    else if i64Size div i64KB > 0 then
      Result := Format('%.2f KB', [i64Size / i64KB])
    else
      Result := IntToStr(i64Size) + ' Byte(s)';
  end;

  function GetFileSize(ADatabaseName: String): Int64;
{  var
    Handle: tHandle;
    FindData: tWin32FindData;
    DatabaseName: String;    // ������ �������� �����, ������ �������� ����������
  begin
    Result := -1;
    if  AnsiPos('localhost:', ADatabaseName) <> 0 then
      DatabaseName := StringReplace(ADatabaseName, 'localhost:', '', [rfIgnoreCase])
    else
      DatabaseName := ADatabaseName;
    Handle := FindFirstFile(PChar(DatabaseName), FindData);
    if Handle = INVALID_HANDLE_VALUE then
    begin
      raise EgsDBSqueeze.Create('Error: FindFirstFile returned Handle = INVALID_HANDLE_VALUE');
    end
    else begin
      Windows.FindClose(Handle);
      if (FindData.dwFileAttributes and FILE_ATTRIBUTE_DIRECTORY) <> 0 then
        Result := 0  // ������ �������� ������ ������� ������ 0
      else begin
        Int64Rec(Result).Hi := FindData.nFileSizeHigh;
        Int64Rec(Result).Lo := FindData.nFileSizeLow;
      end;
    end;
  end;  }
  var
  SearchRecord : TSearchRec;
  DatabaseName: String;
  begin
    Result := -1;
    if  AnsiPos('localhost:', ADatabaseName) <> 0 then
      DatabaseName := StringReplace(ADatabaseName, 'localhost:', '', [rfIgnoreCase])
    else
      DatabaseName := ADatabaseName;
    if FindFirst(DatabaseName, faAnyFile, SearchRecord) = 0 then
    begin
      try
        Result := (SearchRecord.FindData.nFileSizeHigh * Int64(MAXDWORD)) + SearchRecord.FindData.nFileSizeLow;
      finally
        FindClose(SearchRecord);
      end;
    end;
  end;   

var
  FileSize: Int64;  // ������ ����� � ������
begin
  if not FIsProcTablesFinish then
    FileSize := GetFileSize(FConnectInfo.DatabaseName)  //////TODO ���� ���������
  else if FRestoreDBName > '' then
    FileSize := GetFileSize(FRestoreDBName)
  else
    FileSize := GetFileSize(FConnectInfo.DatabaseName);

  FOnGetDBSizeEvent(BytesToStr(FileSize), FileSize);
end;

procedure TgsDBSqueeze.GetStatisticsEvent;
var
  q1, q2, q3, q4: TIBSQL;
  Tr: TIBTransaction;
begin
  LogEvent('Getting statistics...');
  ProgressMsgEvent('��������� ����������...');
  Assert(Connected);

  Tr := TIBTransaction.Create(nil);
  q1 := TIBSQL.Create(nil);
  q2 := TIBSQL.Create(nil);
  q3 := TIBSQL.Create(nil);
  q4 := TIBSQL.Create(nil);
  try
    Tr.DefaultDatabase := FIBDatabase;
    Tr.StartTransaction;

    q1.Transaction := Tr;
    q2.Transaction := Tr;
    q3.Transaction := Tr;
    q4.Transaction := Tr;

    q1.SQL.Text :=
      'SELECT COUNT(id) AS Kolvo FROM gd_document';
    ExecSqlLogEvent(q1, 'GetStatisticsEvent');

    q2.SQL.Text :=
      'SELECT COUNT(id) AS Kolvo FROM ac_entry';
    ExecSqlLogEvent(q2, 'GetStatisticsEvent');

    q3.SQL.Text :=
      'SELECT COUNT(id) AS Kolvo FROM inv_movement';
    ExecSqlLogEvent(q3, 'GetStatisticsEvent');

    q4.SQL.Text :=
      'SELECT COUNT(id) AS Kolvo FROM inv_card';
    ExecSqlLogEvent(q4, 'GetStatisticsEvent');

    FOnGetStatistics(
      q1.FieldByName('Kolvo').AsString,
      q2.FieldByName('Kolvo').AsString,
      q3.FieldByName('Kolvo').AsString,
      q4.FieldByName('Kolvo').AsString
    );

    Tr.Commit;
    ProgressMsgEvent('');
    LogEvent('Getting statistics... OK');
  finally
    q1.Free;
    q2.Free;
    q3.Free;
    q4.Free;
    Tr.Free;
  end;
end;

procedure TgsDBSqueeze.GetProcStatisticsEvent;                                  
var
  q1, q2, q3, q4: TIBSQL;
  Tr: TIBTransaction;
begin
  Assert(Connected);
  LogEvent('Getting processing statistics...');

  Tr := TIBTransaction.Create(nil);
  q1 := TIBSQL.Create(nil);
  q2 := TIBSQL.Create(nil);
  q3 := TIBSQL.Create(nil);
  q4 := TIBSQL.Create(nil);
  try
    Tr.DefaultDatabase := FIBDatabase;
    Tr.StartTransaction;

    q1.Transaction := Tr;
    q2.Transaction := Tr;
    q3.Transaction := Tr;
    q4.Transaction := Tr;

    q1.SQL.Text :=
      'SELECT COUNT(doc.id) AS Kolvo ' +                #13#10 +
      'FROM gd_document doc ' +                         #13#10 +
      'WHERE doc.documentdate < :ClosingDate ';
    if FOnlyCompanySaldo then
    begin                                               
      q1.SQL.Add(' ' +                                  #13#10 +
        'AND (doc.companykey = :Companykey) ');
      q1.ParamByName('Companykey').AsInteger := FCompanyKey;
    end;
    q1.ParamByName('ClosingDate').AsDateTime := FClosingDate;
    ExecSqlLogEvent(q1, 'GetProcStatisticsEvent');

   {q2.SQL.Text :=
      'SELECT COUNT(ae.id) AS Kolvo ' +
      'FROM AC_ENTRY ae ' +
      'WHERE (ae.documentkey IN (SELECT doc.id FROM gd_document doc WHERE doc.documentdate < :ClosingDate)) OR ' +
      '  (ae.masterdockey  IN (SELECT doc.id FROM gd_document doc WHERE doc.documentdate < :ClosingDate)) ';
    q2.ParamByName('ClosingDate').AsDateTime := FClosingDate;
    ExecSqlLogEvent(q2, 'GetProcStatisticsEvent');       }

    q2.SQL.Text :=
      'SELECT COUNT(ae.id) AS Kolvo ' +                 #13#10 +
      'FROM ac_entry ae ' +                             #13#10 +
      'WHERE (ae.entrydate < :ClosingDate) ';
    if FOnlyCompanySaldo then
    begin
      q2.SQL.Add(' ' +                                  #13#10 +
        'AND (ae.companykey = :Companykey) ');
      q2.ParamByName('Companykey').AsInteger := FCompanyKey;
    end;
    q2.ParamByName('ClosingDate').AsDateTime := FClosingDate;
    ExecSqlLogEvent(q2, 'GetProcStatisticsEvent');

  {  q3.SQL.Text :=
      'SELECT COUNT(im.id) AS Kolvo ' +
      'FROM INV_MOVEMENT im ' +
      'WHERE (im.documentkey IN (SELECT doc.id FROM gd_document doc WHERE doc.documentdate < :ClosingDate)) ';
    q3.ParamByName('ClosingDate').AsDateTime := FClosingDate;
    ExecSqlLogEvent(q3, 'GetProcStatisticsEvent');   }

    q3.SQL.Text :=
      'SELECT COUNT(im.id) AS Kolvo ' +                 #13#10 +
      'FROM ' +                                         #13#10 +
      '  inv_movement im ' +                            #13#10 +
      '  JOIN INV_CARD ic ON im.cardkey = ic.id ' +     #13#10 +
      'WHERE ' +                                        #13#10 +
      '  im.movementdate < :ClosingDate ' +             #13#10 +
      '  AND im.disabled = 0 ';
    if FOnlyCompanySaldo then
    begin
      q3.SQL.Add(' ' +                                  #13#10 +
        'AND ic.companykey = :CompanyKey ');
      q3.ParamByName('Companykey').AsInteger := FCompanyKey;
    end;
    q3.ParamByName('ClosingDate').AsDateTime := FClosingDate;
    ExecSqlLogEvent(q3, 'GetProcStatisticsEvent');

    q4.SQL.Text :=
      'SELECT COUNT(ic.id) AS Kolvo ' +                  #13#10 +
      'FROM inv_card ic ' +                              #13#10 +
      'WHERE ' +                                         #13#10 +
      '  ic.documentkey IN (' +                          #13#10 +
      '    SELECT doc.id ' +                             #13#10 +
      '    FROM gd_document doc ' +                      #13#10 +
      '    WHERE doc.documentdate < :ClosingDate ' +     #13#10 +
      '  ) ';
    q4.ParamByName('ClosingDate').AsDateTime := FClosingDate;
    ExecSqlLogEvent(q4, 'GetProcStatisticsEvent');

    FOnGetProcStatistics(
      q1.FieldByName('Kolvo').AsString,
      q2.FieldByName('Kolvo').AsString,
      q3.FieldByName('Kolvo').AsString,
      q4.FieldByName('Kolvo').AsString
    );

    Tr.Commit;
    LogEvent('Getting processing statistics... OK');
    ProgressMsgEvent(' ');
  finally
    q1.Free;
    q2.Free;
    q3.Free;
    q4.Free;
    Tr.Free;
  end;
end;

procedure TgsDBSqueeze.GetDBPropertiesEvent;
var
  DBInfo: TIBDatabaseInfo;
  ODSMajor, ODSMinor: Integer;
  q: TIBSQL;
  Tr: TIBTransaction;
  DBPropertiesList: TStringList; // Association list
begin
  Assert(Connected);

  DBInfo := TIBDatabaseInfo.Create(nil);
  DBInfo.Database := FIBDatabase;
  DBPropertiesList := TStringList.Create;
  Tr := TIBTransaction.Create(nil);
  q := TIBSQL.Create(nil);
  try
    ODSMajor := DBInfo.ODSMajorVersion;
    ODSMinor := DBInfo.ODSMinorVersion;

    try
      case ODSMajor of
        8:
          begin
            if ODSMinor = 0 then
              DBPropertiesList.Append('Server=IB 4.0/4.1')
            else if ODSMinor = 2 then
              DBPropertiesList.Append('Server=IB 4.2')
            else
              raise EgsDBSqueeze.Create('Wrong ODS-version');
          end;
        9:
          begin
            if ODSMinor = 0 then
              DBPropertiesList.Append('Server=IB 5.0/5.1')
            else if ODSMinor = 1 then
              DBPropertiesList.Append('Server=IB 5.5/5.6')
            else
              raise EgsDBSqueeze.Create('Wrong ODS-version');
          end;
        10:
          begin
            if ODSMinor = 0 then
            begin
              DBPropertiesList.Append('Server=FB 1.0/Yaffil');
            end
            else if ODSMinor = 1 then
            begin
              DBPropertiesList.Append('ServerVersion=FB 1.5');
            end
            else
              raise EgsDBSqueeze.Create('Wrong ODS-version');
          end;
        11:
          begin
            case ODSMinor of
              0: DBPropertiesList.Append('Server=FB 2.0');
              1: DBPropertiesList.Append('Server=FB 2.1');
              2: DBPropertiesList.Append('Server=FB 2.5');
            else
              raise EgsDBSqueeze.Create('Wrong ODS-version');
            end;
          end;
        12:
          begin
            if ODSMinor = 0 then
              DBPropertiesList.Append('Server=IB 2007')
            else
              raise EgsDBSqueeze.Create('Wrong ODS-version');
          end;
        13:
          begin
            if ODSMinor = 1 then
              DBPropertiesList.Append('Server=IB 2009')
            else
              raise EgsDBSqueeze.Create('Wrong ODS-version');
          end;
        15:
          begin
            if ODSMinor = 0 then
              DBPropertiesList.Append('Server=IB XE/XE3')
            else
              raise EgsDBSqueeze.Create('Wrong ODS-version');
          end;
      else
        raise EgsDBSqueeze.Create('Wrong ODS-version');
      end;
    except
      on E: EgsDBSqueeze do
      raise EgsDBSqueeze.Create(E.Message+ ': ' + IntToStr(ODSMajor) + '.' +  IntToStr(ODSMinor));
    end;

    Tr.DefaultDatabase := FIBDatabase;
    Tr.StartTransaction;
    q.Transaction := Tr;

    DBPropertiesList.Append('DBName=' + DBInfo.DBFileName);
    DBPropertiesList.Append('ODS=' + IntToStr(ODSMajor) + '.' + IntToStr(ODSMinor));
    DBPropertiesList.Append('PageSize=' + IntToStr(DBInfo.PageSize));
    DBPropertiesList.Append('SQLDialect=' + IntToStr(DBInfo.DBSQLDialect));
    DBPropertiesList.Append('ForcedWrites=' + IntToStr(DBInfo.ForcedWrites));

    FDBPageSize := DBInfo.PageSize;
    
    if RelationExist2('MON$DATABASE', Tr) then
    begin
      q.SQL.Text :=
        'SELECT ' +                                             #13#10 +
        '  mon$database_name   AS DBName, ' +                   #13#10 +
        '  mon$ods_major||''.''||mon$ods_minor AS ODS, ' +      #13#10 +
        '  mon$page_size       AS PageSize, ' +                 #13#10 +
        '  mon$page_buffers    AS PageBuffers, ' +              #13#10 +
        '  mon$sql_dialect     AS SQLDialect, ' +               #13#10 +
        '  mon$forced_writes   AS ForcedWrites ' +              #13#10 +
        'FROM mon$database ';
      ExecSqlLogEvent(q, 'GetDBPropertiesEvent');

      FDBPageBuffers :=  q.FieldByName('PageBuffers').AsInteger;

      DBPropertiesList.Append('PageBuffers=' + q.FieldByName('PageBuffers').AsString);
      q.Close;
    end
    else begin
      DBPropertiesList.Append('PageBuffers=' + '-');
    end;

    if RelationExist2('MON$ATTACHMENTS', Tr) then
    begin
      q.SQL.Text :=
        'SELECT ' +                                             #13#10 +
        '  mon$user               AS U, ' +                     #13#10 +
        '  mon$remote_protocol    AS RemProtocol, ' +           #13#10 +
        '  mon$remote_address     AS RemAddress, ' +            #13#10 +
        '  mon$garbage_collection AS GarbCollection ' +         #13#10 +
        'FROM mon$attachments ' +                               #13#10 +
        'WHERE mon$attachment_id = CURRENT_CONNECTION ';
      ExecSqlLogEvent(q, 'GetDBPropertiesEvent');
      DBPropertiesList.Append('User=' + Trim(q.FieldByName('U').AsString));
      DBPropertiesList.Append('RemoteProtocol=' + Trim(q.FieldByName('RemProtocol').AsString));
      DBPropertiesList.Append('RemoteAddress=' + q.FieldByName('RemAddress').AsString);
      DBPropertiesList.Append('GarbageCollection=' + q.FieldByName('GarbCollection').AsString);
      q.Close;
    end
    else begin
      DBPropertiesList.Append('User=' + '-');
      DBPropertiesList.Append('RemoteProtocol=' + '-');
      DBPropertiesList.Append('RemoteAddress=' + '-');
      DBPropertiesList.Append('GarbageCollection=' + '-');
    end;

    

    FOnGetDBPropertiesEvent(DBPropertiesList);

    Tr.Commit;
  finally
    FreeAndNil(DBInfo);
    DBPropertiesList.Free;
    q.Free;
    Tr.Free;
  end;
end;

procedure TgsDBSqueeze.GetInfoTestConnectEvent;                                 
var
  InfConnectList: TStringList;
  DBInfo: TIBDatabaseInfo;
  ODSMajor, ODSMinor: Integer;
begin
  if Connected then
  begin
    DBInfo := TIBDatabaseInfo.Create(nil);
    DBInfo.Database := FIBDatabase;
    InfConnectList := TStringList.Create;
    try
      ODSMajor := DBInfo.ODSMajorVersion;
      ODSMinor := DBInfo.ODSMinorVersion;

      InfConnectList.Append('ActivConnectCount=' + IntToStr((DBInfo.UserNames).Count));

      try
        case ODSMajor of
          8:
            begin
              InfConnectList.Append('ServerName=InterBase');
              if ODSMinor = 0 then
                InfConnectList.Append('ServerVersion=4.0/4.1')
              else if ODSMinor = 2 then
                InfConnectList.Append('ServerVersion=4.2')
              else
                raise EgsDBSqueeze.Create('Wrong ODS-version');
            end;
          9:
            begin
              InfConnectList.Append('ServerName=InterBase');
              if ODSMinor = 0 then
                InfConnectList.Append('ServerVersion=5.0/5.1')
              else if ODSMinor = 1 then
                InfConnectList.Append('ServerVersion=5.5/5.6')
              else
                raise EgsDBSqueeze.Create('Wrong ODS-version');
            end;
          10:
            begin
              if ODSMinor = 0 then
              begin
                InfConnectList.Append('ServerName=Firebird/Yaffil');
                InfConnectList.Append('ServerVersion=1.0');
              end
              else if ODSMinor = 1 then
              begin
                InfConnectList.Append('ServerName=Firebird');
                InfConnectList.Append('ServerVersion=1.5');
              end
              else
                raise EgsDBSqueeze.Create('Wrong ODS-version');
            end;
          11:
            begin
              InfConnectList.Append('ServerName=Firebird');
              case ODSMinor of
                0: InfConnectList.Append('ServerVersion=2.0');
                1: InfConnectList.Append('ServerVersion=2.1');
                2: InfConnectList.Append('ServerVersion=2.5');
              else
                raise EgsDBSqueeze.Create('Wrong ODS-version');
              end;
            end;
          12:
            begin
              InfConnectList.Append('ServerName=InterBase');
              if ODSMinor = 0 then
                InfConnectList.Append('ServerVersion=2007')
              else
                raise EgsDBSqueeze.Create('Wrong ODS-version');
            end;
          13:
            begin
              InfConnectList.Append('ServerName=InterBase');
              if ODSMinor = 1 then
                InfConnectList.Append('ServerVersion=2009')
              else
                raise EgsDBSqueeze.Create('Wrong ODS-version');
            end;
          15:
            begin
              InfConnectList.Append('ServerName=InterBase');
              if ODSMinor = 0 then
                InfConnectList.Append('ServerVersion=XE/XE3')
              else
                raise EgsDBSqueeze.Create('Wrong ODS-version');
            end;
        else
          raise EgsDBSqueeze.Create('Wrong ODS-version');
        end;
      except
        on E: EgsDBSqueeze do
        raise EgsDBSqueeze.Create(E.Message+ ': ' + IntToStr(ODSMajor) + '.' +  IntToStr(ODSMinor));
      end;

      FOnGetInfoTestConnectEvent(True, InfConnectList);
    finally
      InfConnectList.Free;
      FreeAndNil(DBInfo);
    end;
  end
  else
    FOnGetInfoTestConnectEvent(False, nil);
end;

procedure TgsDBSqueeze.ClearDBSTables;
var
  q: TIBSQL;
  Tr: TIBTransaction;
begin
  Assert(Connected);

  Tr := TIBTransaction.Create(nil);
  q := TIBSQL.Create(nil);
  try
    Tr.DefaultDatabase := FIBDatabase;
    Tr.StartTransaction;
    q.Transaction := Tr;

    try
      q.SQL.Text := 'DROP TABLE DBS_TMP_PROCESSED_TABLES';
      ExecSqlLogEvent(q, 'ClearDBSTables');

      q.SQL.Text := 'DROP TABLE DBS_TMP_REBIND_INV_CARDS';
      ExecSqlLogEvent(q, 'ClearDBSTables');

      {q.SQL.Text := 'DROP TABLE DBS_TMP_AC_SALDO'; }
      q.SQL.Text := 'DELETE FROM DBS_TMP_AC_SALDO';
      ExecSqlLogEvent(q, 'ClearDBSTables');

      q.SQL.Text := 'DROP TABLE DBS_TMP_INV_SALDO';
      ExecSqlLogEvent(q, 'ClearDBSTables');

      q.SQL.Text := 'DROP TABLE DBS_TMP_INV_CARD';
      ExecSqlLogEvent(q, 'ClearDBSTables');

      q.SQL.Text := 'DROP TABLE DBS_INACTIVE_TRIGGERS';
      ExecSqlLogEvent(q, 'ClearDBSTables');

      q.SQL.Text := 'DROP TABLE DBS_INACTIVE_INDICES';
      ExecSqlLogEvent(q, 'ClearDBSTables');

      q.SQL.Text := 'DROP TABLE DBS_PK_UNIQUE_CONSTRAINTS';
      ExecSqlLogEvent(q, 'ClearDBSTables');

      q.SQL.Text := 'DROP TABLE DBS_SUITABLE_TABLES';
      ExecSqlLogEvent(q, 'ClearDBSTables');

      q.SQL.Text := 'DROP TABLE DBS_FK_CONSTRAINTS';
      ExecSqlLogEvent(q, 'ClearDBSTables');

      q.SQL.Text := 'DROP TABLE DBS_TMP_FK_CONSTRAINTS';
      ExecSqlLogEvent(q, 'ClearDBSTables');

      Tr.Commit;

      DropDBSStateJournal;
    except
      on E: Exception do
      begin
        //Tr.Rollback;
        ErrorEvent('������ ��� �������� �������: ' + E.Message);
      end;
    end;
  finally
    q.Free;
    Tr.Free;
  end;
end;

procedure TgsDBSqueeze.ProgressWatchEvent(const AProgressInfo: TgdProgressInfo);
begin
  FOnProgressWatch(Self, AProgressInfo);
end;

procedure TgsDBSqueeze.LogEvent(const AMsg: String);
var
  PI: TgdProgressInfo;
begin
  if Assigned(FOnProgressWatch) then
  begin
    PI.State := psMessage;
    PI.Message := AMsg;
    ProgressWatchEvent(PI);
  end;
end;

procedure TgsDBSqueeze.ProgressMsgEvent(const AMsg: String; AStepIncrement: Integer = 1);
var
  PI: TgdProgressInfo;
begin
  if Assigned(FOnProgressWatch) then
  begin
    FCurrentProgressStep :=  FCurrentProgressStep + AStepIncrement;

    PI.State := psProgress;
    PI.CurrentStep := FCurrentProgressStep;
    PI.CurrentStepName := AMsg;
    ProgressWatchEvent(PI);
  end;
end;

procedure TgsDBSqueeze.ErrorEvent(const AMsg: String; const AProcessName: String = '');
var
  PI: TgdProgressInfo;
begin
  if Assigned(FOnProgressWatch) then
  begin
    PI.State := psError;
    PI.ProcessName := AProcessName;
    PI.Message := AMsg;
    ProgressWatchEvent(PI);
  end;
end;
end.
