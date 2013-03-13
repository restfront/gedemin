unit gsDBSqueeze_unit;

interface

uses
  IB, IBDatabase, IBSQL;

type
  TOnLogEvent = procedure(const S: String) of object;

  TgsDBSqueeze = class(TObject)
  private
    FIBSQL: TIBSQL;

    FUserName: String;
    FPassword: String;
    FDatabaseName: String;
    FIBDatabase: TIBDatabase;
    FOnLogEvent: TOnLogEvent;

    function GetConnected: Boolean;


    function h_CreateTblForSaveFK: Boolean;
    function h_CreateTblForSavePkUnique: Boolean;
  //  function h_CreateTblForSaveNotNull: Boolean;
    procedure h_InsertTblForSaveFK;
    procedure h_InsertTblForSavePkUnique;
  //  procedure h_InsertTblForSaveNotNull;
    procedure h_SaveFKConstr;
    procedure h_SavePkUniqueConstr;
  //  procedure h_SaveNotNullConstr;

    procedure h_SaveAllConstr;

    procedure h_DeleteFKConstr;
    procedure h_DeletePkUniqueConstr;
 //   procedure h_DeleteNotNullConstr;

    procedure h_DeleteAllConstr;

    procedure h_RecreateFKConstr;
    procedure h_RecreatePkUniqueConstr;
 //   procedure h_RecreateNotNullConstr;

    procedure h_RecreateAllConstr;

 //   procedure h_SwitchActivityIndices(AEnableFlag: Integer);

    procedure LogEvent(const AMsg: String);

  public
    constructor Create;
    destructor Destroy; override;

    procedure Connect;
    procedure Disconnect;

    procedure BeforeMigrationPrepareDB;
    procedure AfterMigrationPrepareDB;

    property DatabaseName: String read FDatabaseName write FDatabaseName;
    property UserName: String read FUserName write FUserName;
    property Password: String read FPassword write FPassword;
    property Connected: Boolean read GetConnected;
    property OnLogEvent: TOnLogEvent read FOnLogEvent write FOnLogEvent;

  end;

implementation

{ TgsDBSqueeze }

procedure TgsDBSqueeze.Connect;
begin
  FIBDatabase.DatabaseName := FDatabaseName;
  FIBDatabase.LoginPrompt := False;
  FIBDatabase.Params.Text :=
    'user_name=' + FUserName + #13#10 +
    'password=' + FPassword + #13#10 +
    'lc_ctype=win1251';
  FIBDatabase.Connected := True;
  LogEvent('Connecting to DB ... OK');
end;

constructor TgsDBSqueeze.Create;
begin
  inherited;
  FIBDatabase := TIBDatabase.Create(nil);
  FIBSQL := TIBSQL.Create(nil);
end;

destructor TgsDBSqueeze.Destroy;
begin
  if Connected then
    Disconnect;
  FIBDatabase.Free;

  FIBSQL.Free;

  inherited;
end;

procedure TgsDBSqueeze.Disconnect;
begin
  FIBDatabase.Connected := False;
  LogEvent('Disconnecting to DB ... OK');
end;

function TgsDBSqueeze.GetConnected: Boolean;
begin
  Result := FIBDatabase.Connected;
end;



function TgsDBSqueeze.h_CreateTblForSaveFK: Boolean;
var
  q, q2: TIBSQL;
  Tr: TIBTransaction;
begin
  Assert(Connected);
  q := TIBSQL.Create(nil);
  q2 := TIBSQL.Create(nil);
  Tr := TIBTransaction.Create(nil);

  try
    Tr.DefaultDatabase := FIBDatabase;
    Tr.StartTransaction;

    q.Transaction := Tr;
    q2.Transaction := Tr;

    q.SQL.Text :=
      'SELECT * FROM RDB$RELATIONS WHERE RDB$RELATION_NAME = :RN ';
    q.ParamByName('RN').AsString := 'DBS_FK_CONSTRAINTS';
    q.ExecQuery;
    if q.EOF then
    begin
      q2.SQL.Text := 'CREATE TABLE DBS_FK_CONSTRAINTS ( ' +
        ' RELATION_NAME     CHAR(31), ' +
        ' CONSTRAINT_NAME   CHAR(31), ' +
        ' LIST_FIELDS       VARCHAR(310), ' +
        ' REF_RELATION_NAME CHAR(31), ' +
        ' LIST_REF_FIELDS   VARCHAR(310), ' +
        ' UPDATE_RULE       CHAR(11), ' +
        ' DELETE_RULE       CHAR(11), ' +
        'PRIMARY KEY (CONSTRAINT_NAME)) ';
      q2.ExecQuery;
      q2.Close;
      LogEvent('DBS_FK_CONSTRAINTS table has been created.');
      Result := True;
    end
    else
    begin
      LogEvent('DBS_FK_CONSTRAINTS table HASN''T been created.');
      Result := False;
    end;
    q.Close;

    Tr.Commit;
  finally
    q.Free;
    q2.Free;
    Tr.Free;
  end;
end;

function TgsDBSqueeze.h_CreateTblForSavePkUnique: Boolean;
var
  q, q2: TIBSQL;
  Tr: TIBTransaction;
begin
  Assert(Connected);
  q := TIBSQL.Create(nil);
  q2 := TIBSQL.Create(nil);
  Tr := TIBTransaction.Create(nil);

  try
    Tr.DefaultDatabase := FIBDatabase;
    Tr.StartTransaction;

    q.Transaction := Tr;
    q2.Transaction := Tr;

    q.SQL.Text :=
      'SELECT * FROM RDB$RELATIONS WHERE RDB$RELATION_NAME = :RN ';
    q.ParamByName('RN').AsString := 'DBS_PK_UNIQUE_CONSTRAINTS';
    q.ExecQuery;
    if q.EOF then
    begin
      q2.SQL.Text := 'CREATE TABLE DBS_PK_UNIQUE_CONSTRAINTS ( ' +
        ' RELATION_NAME     CHAR(31), ' +
        ' CONSTRAINT_NAME   CHAR(31), ' +
        ' CONSTRAINT_TYPE   CHAR(11), ' +
        ' LIST_FIELDS       VARCHAR(310), ' +
        ' PRIMARY KEY (CONSTRAINT_NAME)) ';
      q2.ExecQuery;
      q2.Close;
      LogEvent('DBS_PK_UNIQUE_CONSTRAINTS table has been created.');
      Result := True;
    end
    else
    begin
      LogEvent('DBS_PK_UNIQUE_CONSTRAINTS table HASN''T been created.');
      Result := False;
    end;
    q.Close;

    Tr.Commit;
  finally
    q.Free;
    q2.Free;
    Tr.Free;
  end;
end;


procedure TgsDBSqueeze.h_InsertTblForSaveFK;
var
  q: TIBSQL;
  Tr: TIBTransaction;
begin
  Assert(Connected);
  q := TIBSQL.Create(nil);
  Tr := TIBTransaction.Create(nil);
  try
    Tr.DefaultDatabase := FIBDatabase;
    Tr.StartTransaction;

    q.Transaction := Tr;

    q.SQL.Text :='INSERT INTO DBS_FK_CONSTRAINTS ( ' +
      ' RELATION_NAME, ' +
      ' CONSTRAINT_NAME, ' +
      ' LIST_FIELDS, ' +
      ' REF_RELATION_NAME, ' +
      ' LIST_REF_FIELDS, ' +
      ' UPDATE_RULE, ' +
      ' DELETE_RULE ) ' +
      'SELECT ' +
      '  c.RDB$RELATION_NAME, ' +
      '  c.RDB$CONSTRAINT_NAME, ' +
      '  i.List_Fields, ' +
      '  c2.RDB$RELATION_NAME, ' +
      ' i2.List_Fields2, ' +
      ' refc.RDB$UPDATE_RULE, ' +
      ' refc.RDB$DELETE_RULE ' +
      'FROM RDB$RELATION_CONSTRAINTS c ' +
      '  JOIN (SELECT inx.rdb$INDEX_NAME, ' +
      '    list(inx.RDB$FIELD_NAME) as List_Fields ' +
      '    FROM RDB$INDEX_SEGMENTS inx ' +
      '    GROUP BY inx.rdb$INDEX_NAME ' +
      '  ) i ON c.rdb$INDEX_NAME = i.rdb$INDEX_NAME ' +
      '  JOIN RDB$REF_CONSTRAINTS refc ON c.RDB$CONSTRAINT_NAME = refc.RDB$CONSTRAINT_NAME ' +
      '  JOIN RDB$RELATION_CONSTRAINTS c2 ON refc.RDB$CONST_NAME_UQ = c2.RDB$CONSTRAINT_NAME ' +
      '  JOIN (SELECT inx.rdb$INDEX_NAME, ' +
      '    list(inx.RDB$FIELD_NAME) as List_Fields2 ' +
      '    FROM RDB$INDEX_SEGMENTS inx ' +
      '  GROUP BY inx.rdb$INDEX_NAME' +
      '  ) i2 ON c2.rdb$INDEX_NAME = i2.rdb$INDEX_NAME ' +
      'WHERE c.rdb$constraint_type = ''FOREIGN KEY'' ' +
      '  AND NOT c.rdb$relation_name LIKE ''RDB$%'' ';                           //
    q.ExecQuery;
    q.Close;

    Tr.Commit;
    LogEvent('Inserting in tables for saving FK constraints ... OK');
  finally
    q.Free;
    Tr.Free;
  end;
end;

procedure TgsDBSqueeze.h_InsertTblForSavePkUnique;
var
  q: TIBSQL;
  Tr: TIBTransaction;
begin
  Assert(Connected);
  q := TIBSQL.Create(nil);
  Tr := TIBTransaction.Create(nil);
  try
    Tr.DefaultDatabase := FIBDatabase;
    Tr.StartTransaction;

    q.Transaction := Tr;

    q.SQL.Text := 'INSERT INTO DBS_PK_UNIQUE_CONSTRAINTS ( ' +
      ' RELATION_NAME, ' +
      ' CONSTRAINT_NAME, ' +
      ' CONSTRAINT_TYPE, ' +
      ' LIST_FIELDS ) ' +
      'SELECT ' +
      '  c.RDB$RELATION_NAME, ' +
      '  c.RDB$CONSTRAINT_NAME, ' +
      '  c.RDB$CONSTRAINT_TYPE, ' +
      '  i.List_Fields ' +
      'FROM RDB$RELATION_CONSTRAINTS c ' +
      '  JOIN (SELECT inx.rdb$INDEX_NAME, ' +
      '    list(inx.RDB$FIELD_NAME) as List_Fields ' +
      '    FROM RDB$INDEX_SEGMENTS inx ' +
      '    GROUP BY inx.rdb$INDEX_NAME ' +
      '  ) i ON c.rdb$INDEX_NAME = i.rdb$INDEX_NAME ' +
      'WHERE (c.rdb$constraint_type = ''PRIMARY KEY'' OR c.rdb$constraint_type = ''UNIQUE'') ' +
      '  AND NOT c.rdb$relation_name LIKE ''RDB$%'' ';                           //
    q.ExecQuery;
    q.Close;

    Tr.Commit;
    LogEvent('Inserting in tables for saving PK and UNIQUE constraints ... OK');
  finally
    q.Free;
    Tr.Free;
  end;
end;

procedure TgsDBSqueeze.h_SaveFKConstr;
var
  q: TIBSQL;
  Tr: TIBTransaction;
begin
  Assert(Connected);
  q := TIBSQL.Create(nil);
  Tr := TIBTransaction.Create(nil);
  LogEvent('[1]Saving FK constraints ... ');
  if not h_CreateTblForSaveFK then
  begin
    try
      Tr.DefaultDatabase := FIBDatabase;
      Tr.StartTransaction;

      q.Transaction := Tr;

      q.SQL.Text := 'DELETE FROM DBS_FK_CONSTRAINTS ';
      q.ExecQuery;
      q.Close;

      Tr.Commit;
      LogEvent('Deleting data from DBS_FK_CONSTRAINTS ... OK');
    finally
      q.Free;
      Tr.Free;
    end;
  end;

  h_InsertTblForSaveFK;
  LogEvent('[1]Saving FK constraints ... OK');
end;

procedure TgsDBSqueeze.h_SavePkUniqueConstr;
var
  q: TIBSQL;
  Tr: TIBTransaction;
begin
  LogEvent('[2]Saving PK and UNIQUE constraints ... ');

  Assert(Connected);
  q := TIBSQL.Create(nil);
  Tr := TIBTransaction.Create(nil);

  if not h_CreateTblForSavePkUnique then
  begin
    try
      Tr.DefaultDatabase := FIBDatabase;
      Tr.StartTransaction;

      q.Transaction := Tr;

      q.SQL.Text := 'DELETE FROM DBS_PK_UNIQUE_CONSTRAINTS ';
      q.ExecQuery;
      q.Close;

      Tr.Commit;
      LogEvent('Deleting data from DBS_PK_UNIQUE_CONSTRAINTS ... OK');
    finally
      q.Free;
      Tr.Free;
    end;
  end;

  h_InsertTblForSavePkUnique;
  LogEvent('[2]Saving PK and UNIQUE constraints ... OK');
end;

procedure TgsDBSqueeze.h_SaveAllConstr;
begin

  LogEvent('Saving All constraints ...');

  h_SaveFKConstr;
  h_SavePkUniqueConstr;
  //...

  LogEvent('Saving All constraints ... OK');
end;

procedure TgsDBSqueeze.h_DeleteFKConstr;
var
  textSql: String;
  q, q2:  TIBSQL;
  Tr: TIBTransaction;
begin
  Assert(Connected);

  q := TIBSQL.Create(nil);
  q2 := TIBSQL.Create(nil);
  Tr := TIBTransaction.Create(nil);
  try
    Tr.DefaultDatabase := FIBDatabase;
    Tr.StartTransaction;

    q.Transaction := Tr;
    q2.Transaction := Tr;

    q.SQL.Text :=
      'SELECT c.RDB$RELATION_NAME as Relation_Name, ' +
        'c.RDB$CONSTRAINT_NAME as Constraint_Name ' +
      'FROM RDB$RELATION_CONSTRAINTS c ' +
        'JOIN RDB$INDICES i ON i.RDB$INDEX_NAME = c.RDB$INDEX_NAME ' +
      'WHERE c.RDB$CONSTRAINT_TYPE = ''FOREIGN KEY'' AND '+
        '(i.RDB$SYSTEM_FLAG IS NULL OR i.RDB$SYSTEM_FLAG = 0) ';                 //
    q.ExecQuery;
    while not q.Eof do
    begin
      textSql := 'ALTER TABLE ' + q.FieldByName('Relation_Name').AsString +
        ' DROP CONSTRAINT ' + q.FieldByName('Constraint_Name').AsString;

      q2.SQL.Text := textSql;
      q2.ExecQuery;
      q2.Close;

      q.Next;
    end;
    Tr.Commit;
    LogEvent('[1]Deleting FK constraints ... OK');
  finally
    q.Free;
    q2.Free;
    Tr.Free;
  end;
end;

procedure TgsDBSqueeze.h_DeletePkUniqueConstr;
var
  textSql: String;
  q, q2:  TIBSQL;
  Tr: TIBTransaction;
begin
  Assert(Connected);

  q := TIBSQL.Create(nil);
  q2 := TIBSQL.Create(nil);
  Tr := TIBTransaction.Create(nil);
  try
    Tr.DefaultDatabase := FIBDatabase;
    Tr.StartTransaction;

    q.Transaction := Tr;
    q2.Transaction := Tr;

    q.SQL.Text :=
      'SELECT c.RDB$RELATION_NAME as Relation_Name, ' +
        'c.RDB$CONSTRAINT_NAME as Constraint_Name ' +
      'FROM RDB$RELATION_CONSTRAINTS c ' +
        'JOIN RDB$INDICES i ON i.RDB$INDEX_NAME = c.RDB$INDEX_NAME ' +
      'WHERE (c.RDB$CONSTRAINT_TYPE = ''PRIMARY KEY'' OR c.RDB$CONSTRAINT_TYPE = ''UNIQUE'') AND '+
        '(i.RDB$SYSTEM_FLAG IS NULL OR i.RDB$SYSTEM_FLAG = 0) ';                 //
    q.ExecQuery;
    while not q.Eof do
    begin
      textSql := 'ALTER TABLE ' + q.FieldByName('Relation_Name').AsString +
        ' DROP CONSTRAINT ' + q.FieldByName('Constraint_Name').AsString;

      q2.SQL.Text := textSql;
      q2.ExecQuery;
      q2.Close;

      q.Next;
    end;
    Tr.Commit;
    LogEvent('[2]Deleting PK and UNIQUE constraints ... OK');
  finally
    q.Free;
    q2.Free;
    Tr.Free;
  end;
end;

procedure TgsDBSqueeze.h_DeleteAllConstr;
begin
  LogEvent('Deleting All constraints ...');
  h_DeleteFKConstr;
  h_DeletePkUniqueConstr;
  //...
  LogEvent('Deleting All constraints ... OK');
end;


procedure TgsDBSqueeze.h_RecreateFKConstr;
var
  textSql: String;
  q, q2: TIBSQL;
  Tr: TIBTransaction;
begin
  Assert(Connected);

  q := TIBSQL.Create(nil);
  q2 := TIBSQL.Create(nil);
  Tr := TIBTransaction.Create(nil);
  try
    Tr.DefaultDatabase := FIBDatabase;
    Tr.StartTransaction;

    q2.Transaction := Tr;

    q.Transaction := Tr;
    q.SQL.Text := 'SELECT ' +
      ' RELATION_NAME as Relation_Name, ' +
      ' CONSTRAINT_NAME as Constraint_Name, ' +
      ' LIST_FIELDS as List_Fields, ' +
      ' REF_RELATION_NAME as Ref_Relation_Name, ' +
      ' LIST_REF_FIELDS as List_Ref_Fields, ' +
      ' UPDATE_RULE as Update_Rule, ' +
      ' DELETE_RULE as Delete_Rule ' +
      'FROM DBS_FK_CONSTRAINTS ';
    q.ExecQuery;
    while not q.EOF do
    begin
      textSql :=
        'ALTER TABLE ' + q.FieldByName('Relation_Name').AsString + ' ADD CONSTRAINT ' +
        q.FieldByName('Constraint_Name').AsString + ' FOREIGN KEY (' +
        q.FieldByName('List_Fields').AsString +  ') REFERENCES ' +
        q.FieldByName('Ref_Relation_Name').AsString + ' (' +
        q.FieldByName('List_Ref_Fields').AsString +') ' +
        ' ON DELETE ' + q.FieldByName('Delete_Rule').AsString +
        ' ON UPDATE ' + q.FieldByName('Update_Rule').AsString;
      q2.SQL.Text := textSql;
      q2.ExecQuery;

      q.Next;
    end;
    Tr.Commit;
    LogEvent('[1]Recreating FK constraints ... OK');

    //��������  DBS_FK_CONSTRAINTS �� �������������
  finally
    q.Free;
    q2.Free;
    Tr.Free;
  end;
end;

procedure TgsDBSqueeze.h_RecreatePkUniqueConstr;
var
  textSql: String;
  q, q2: TIBSQL;
  Tr: TIBTransaction;
begin
  Assert(Connected);

  q := TIBSQL.Create(nil);
  q2 := TIBSQL.Create(nil);
  Tr := TIBTransaction.Create(nil);
  try
    Tr.DefaultDatabase := FIBDatabase;
    Tr.StartTransaction;

    q2.Transaction := Tr;

    q.Transaction := Tr;
    q.SQL.Text := 'SELECT ' +
      ' RELATION_NAME as Relation_Name, ' +
      ' CONSTRAINT_NAME as Constraint_Name, ' +
      ' CONSTRAINT_TYPE as Constraint_Type, ' +
      ' LIST_FIELDS as List_Fields ' +
      'FROM  DBS_PK_UNIQUE_CONSTRAINTS ';
    q.ExecQuery;
    while not q.EOF do
    begin
      textSql :=
        'ALTER TABLE ' + q.FieldByName('Relation_Name').AsString + ' ADD CONSTRAINT ' +
        q.FieldByName('Constraint_Name').AsString +  q.FieldByName('Constraint_Type').AsString +
        ' (' + q.FieldByName('List_Fields').AsString +  ') ';
      q2.SQL.Text := textSql;
      q2.ExecQuery;

      q.Next;
    end;
    Tr.Commit;
    LogEvent('[2]Recreating PK and UNIQUE constraints ... OK');

    //�������� DBS_PK_UNIQUE_CONSTRAINTS �� �������������
  finally
    q.Free;
    q2.Free;
    Tr.Free;
  end;
end;



procedure TgsDBSqueeze.h_RecreateAllConstr;
begin
  LogEvent('Recreating All constraints ...');
  h_RecreateFKConstr;
  h_RecreatePkUniqueConstr;
  //...
  LogEvent('Recreating All constraints ... OK');
end;


procedure  TgsDBSqueeze.BeforeMigrationPrepareDB;
begin
  h_SaveAllConstr;
  h_DeleteAllConstr;
  //h_SwitchActivityIndices(0);
  //...
end;

procedure TgsDBSqueeze.AfterMigrationPrepareDB;
begin
  //h_SwitchActivityIndices(1);
  h_RecreateAllConstr;
  //...
end;

procedure TgsDBSqueeze.LogEvent(const AMsg: String);
begin
  if Assigned(FOnLogEvent) then
    FOnLogEvent(AMsg);
end;

{
//ADisableFlag:  0-��������������, 1-������������
procedure TgsDBSqueeze.h_SwitchActivityIndices(AEnableFlag: Integer);    //const
var
  q, q2: TIBSQL;
  Tr: TIBTransaction;
begin
  Assert(Connected);

  q := TIBSQL.Create(nil);
  q2 := TIBSQL.Create(nil);
  Tr := TIBTransaction.Create(nil);
  try
    Tr.DefaultDatabase := FIBDatabase;
    Tr.StartTransaction;

    q2.Transaction := Tr;

    q.Transaction := Tr;
    q.SQL.Text :=  'SELECT i.RDB$INDEX_NAME as Index_Name FROM RDB$INDICES i ' +
      ' WHERE i.RDB$INDEX_INACTIVE = :enableFlag ';
    q.ParamByName('enableFlag').AsInteger := AEnableFlag;
    q.ExecQuery;

    while not q.EOF do
    begin
      q2.SQL.Text := ' UPDATE RDB$INDICES i ' +
        ' SET i.RDB$INDEX_INACTIVE =  :flag ' +
        ' WHERE I.RDB$INDEX_NAME = :index_name ';
      if AEnableFlag = 0 then
        q2.ParamByName('flag').AsInteger := 1
      else if AEnableFlag = 1 then
        q2.ParamByName('flag').AsInteger := 0;

      q2.ParamByName('index_name').AsString := q.FieldByName('Index_Name').AsString;
      q2.ExecQuery;
      q2.Close;

      q.Next;
    end;
    Tr.Commit;

    if AEnableFlag = 0 then
      LogEvent('Deactivation indices ... OK')
    else if AEnableFlag = 1 then
      LogEvent('Activation indices ... OK');
  finally
    q.Free;
    q2.Free;
    Tr.Free;
  end;
end;
}



end.
