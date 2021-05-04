(*

  Trysil
  Copyright � David Lastrucci
  All rights reserved

  Trysil - Operation ORM (World War II)
  http://codenames.info/operation/orm/

*)
unit Trysil.Data.FireDAC.FirebirdSQL.SqlSyntax;

interface

uses
  System.Classes,
  System.SysUtils,
  System.Generics.Collections,
  Data.DB,
  FireDAC.Stan.Param,
  FireDAC.Comp.Client,

  Trysil.Types,
  Trysil.Filter,
  Trysil.Exceptions,
  Trysil.Rtti,
  Trysil.Metadata,
  Trysil.Mapping,
  Trysil.Events.Abstract,
  Trysil.Data.FireDAC.Parameters;

type

{ TTDataFirebirdSQLSequenceSyntax }

  TTDataFirebirdSQLSequenceSyntax = class
  strict private
    FConnection: TFDConnection;
    FSequenceName: String;

    function GetID: TTPrimaryKey;
  public
    constructor Create(
      const AConnection: TFDConnection; const ASequenceName: String);

    property ID: TTPrimaryKey read GetID;
  end;

{ TTDataFirebirdSQLSelectCountSyntax }

  TTDataFirebirdSQLSelectCountSyntax = class
  strict private
    FConnection: TFDConnection;
    FTableMap: TTTableMap;
    FTableName: String;
    FColumnName: String;
    FID: TTPrimaryKey;

    function GetCount: Integer;
  public
    constructor Create(
      const AConnection: TFDConnection;
      const ATableMap: TTTableMap;
      const ATableName: String;
      const AColumnName: String;
      const AID: TTPrimaryKey);

    property Count: Integer read GetCount;
  end;

{ TTDataFirebirdSQLAbstractSqlSyntax }

  TTDataFirebirdSQLAbstractSyntax = class abstract
  strict private
    function GetDataset: TDataset;
  strict protected
    FConnection: TFDConnection;
    FMapper: TTMapper;
    FTableMap: TTTableMap;
    FTableMetadata: TTTableMetadata;
    FDataset: TFDQuery;

    function GetSqlSyntax: String; virtual; abstract;
  public
    constructor Create(
      const AConnection: TFDConnection;
      const AMapper: TTMapper;
      const ATableMap: TTTableMap;
      const ATableMetadata: TTTableMetadata);
    destructor Destroy; override;

    procedure AfterConstruction; override;

    property Dataset: TDataset read GetDataset;
  end;

{ TTDataFirebirdSQLSelectSyntax }

  TTDataFirebirdSQLSelectSyntax = class(TTDataFirebirdSQLAbstractSyntax)
  strict private
    FFilter: TTFilter;

    function GetColumns: String;
    function GetOrderBy: String;
  strict protected
    function GetSqlSyntax: String; override;
  public
    constructor Create(
      const AConnection: TFDConnection;
      const AMapper: TTMapper;
      const ATableMap: TTTableMap;
      const ATableMetadata: TTTableMetadata;
      const AFilter: TTFilter);

    procedure AfterConstruction; override;
  end;

{ TTDataFirebirdSQLMetadataSyntax }

  TTDataFirebirdSQLMetadataSyntax = class(TTDataFirebirdSQLSelectSyntax)
  public
    constructor Create(
      const AConnection: TFDConnection;
      const AMapper: TTMapper;
      const ATableMap: TTTableMap;
      const ATableMetadata: TTTableMetadata);
  end;

{ TTDataFirebirdSQLCommandSyntax }

  TTDataFirebirdSQLCommandSyntax =
    class abstract(TTDataFirebirdSQLAbstractSyntax)
  strict private
    FParameters: TObjectList<TTDataParameter>;

    function GetColumnMap(const AColumnName: String): TTColumnMap;

    procedure CheckReadWrite;
    procedure InitializeParameters;
    procedure AssignParameterValues(const AEntity: TObject);
  strict protected
    procedure BeforeExecute(
      const AEntity: TObject; const AEvent: TTEvent); virtual;
    procedure AfterExecute(
      const AEntity: TObject; const AEvent: TTEvent); virtual;
  public
    constructor Create(
      const AConnection: TFDConnection;
      const AMapper: TTMapper;
      const ATableMap: TTTableMap;
      const ATableMetadata: TTTableMetadata);
    destructor Destroy; override;

    procedure AfterConstruction; override;

    procedure Execute(const AEntity: TObject; const AEvent: TTEvent);
  end;

{ TTDataFirebirdSQLInsertSyntax }

  TTDataFirebirdSQLInsertSyntax = class(TTDataFirebirdSQLCommandSyntax)
  strict private
    function GetColumns: String;
    function GetParameters: String;
  strict protected
    function GetSqlSyntax: String; override;
  end;

{ TTDataFirebirdSQLUpdateSyntax }

  TTDataFirebirdSQLUpdateSyntax = class(TTDataFirebirdSQLCommandSyntax)
  strict private
    function GetColumns: String;
  strict protected
    function GetSqlSyntax: String; override;
  end;

{ TTDataFirebirdSQLDeleteSyntax }

  TTDataFirebirdSQLDeleteSyntax = class(TTDataFirebirdSQLCommandSyntax)
  strict protected
    procedure BeforeExecute(
      const AEntity: TObject; const AEvent: TTEvent); override;
    function GetSqlSyntax: String; override;
  end;

{ resourcestring }

resourcestring
  SReadOnly = '"Primary Key" or "Version Column" are not defined.';
  SColumnNotFound = 'Column %s not found.';
  SRecordChanged = 'Entity modified by another user.';
  SSyntaxError = 'Incorrect syntax: too many records affected.';

implementation

{ TTDataFirebirdSQLSequenceSyntax }

constructor TTDataFirebirdSQLSequenceSyntax.Create(
  const AConnection: TFDConnection; const ASequenceName: String);
begin
  inherited Create;
  FConnection := AConnection;
  FSequenceName := ASequenceName;
end;

function TTDataFirebirdSQLSequenceSyntax.GetID: TTPrimaryKey;
var
  LDataset: TFDQuery;
begin
  LDataset := TFDQuery.Create(nil);
  try
    LDataset.Connection := FConnection;

    LDataset.Open(
      Format('SELECT GEN_ID(%s, 1) ID FROM RDB$DATABASE', [FSequenceName]));
    result := LDataset.Fields[0].AsInteger;
  finally
    LDataset.Free;
  end;
end;

{ TTDataFirebirdSQLSelectCountSyntax }

constructor TTDataFirebirdSQLSelectCountSyntax.Create(
  const AConnection: TFDConnection;
  const ATableMap: TTTableMap;
  const ATableName: String;
  const AColumnName: String;
  const AID: TTPrimaryKey);
begin
  inherited Create;
  FConnection := AConnection;
  FTableMap := ATableMap;
  FTableName := ATableName;
  FColumnName := AColumnName;
  FID := AID;
end;

function TTDataFirebirdSQLSelectCountSyntax.GetCount: Integer;
var
  LDataset: TFDQuery;
begin
  LDataset := TFDQuery.Create(nil);
  try
    LDataset.Connection := FConnection;

    LDataset.Open(Format('SELECT COUNT(*) FROM %0:s WHERE %1:s = %2:d', [
      FTableName, FColumnName, FID]));
    result := LDataset.Fields[0].AsInteger;
  finally
    LDataset.Free;
  end;
end;

{ TTDataFirebirdSQLAbstractSyntax }

constructor TTDataFirebirdSQLAbstractSyntax.Create(
  const AConnection: TFDConnection;
  const AMapper: TTMapper;
  const ATableMap: TTTableMap;
  const ATableMetadata: TTTableMetadata);
begin
  inherited Create;
  FConnection := AConnection;
  FMapper := AMapper;
  FTableMap := ATableMap;
  FTableMetadata := ATableMetadata;

  FDataset := TFDQuery.Create(nil);
end;

destructor TTDataFirebirdSQLAbstractSyntax.Destroy;
begin
  FDataset.Free;
  inherited Destroy;
end;

procedure TTDataFirebirdSQLAbstractSyntax.AfterConstruction;
begin
  inherited AfterConstruction;
  FDataset.Connection := FConnection;
  FDataset.SQL.Text := GetSqlSyntax;
end;

function TTDataFirebirdSQLAbstractSyntax.GetDataset: TDataset;
begin
  result := FDataset;
end;

{ TTDataFirebirdSQLSelectSyntax }

constructor TTDataFirebirdSQLSelectSyntax.Create(
  const AConnection: TFDConnection;
  const AMapper: TTMapper;
  const ATableMap: TTTableMap;
  const ATableMetadata: TTTableMetadata;
  const AFilter: TTFilter);
begin
  inherited Create(AConnection, AMapper, ATableMap, ATableMetadata);
  FFilter := AFilter;
end;

procedure TTDataFirebirdSQLSelectSyntax.AfterConstruction;
begin
  inherited AfterConstruction;
  FDataset.Open;
end;

function TTDataFirebirdSQLSelectSyntax.GetColumns: String;
var
  LResult: TStringBuilder;
  LColumnMap: TTColumnMap;
begin
  LResult := TStringBuilder.Create;
  try
    for LColumnMap in FTableMap.Columns do
      LResult.AppendFormat('%s, ', [LColumnMap.Name]);

    result := LResult.ToString();
    if not result.IsEmpty then
      result := result.Substring(0, result.Length - 2);
  finally
    LResult.Free;
  end;
end;

function TTDataFirebirdSQLSelectSyntax.GetOrderBy: String;
var
  LResult: TStringBuilder;
begin
  LResult := TStringBuilder.Create;
  try
    if (not FFilter.Top.OrderBy.IsEmpty) then
      LResult.AppendFormat(' ORDER BY %s, ', [FFilter.Top.OrderBy])
    else if Assigned(FTableMap.PrimaryKey) then
      LResult.AppendFormat(' ORDER BY %s, ', [FTableMap.PrimaryKey.Name]);

    result := LResult.ToString();
    if not result.IsEmpty then
      result := result.Substring(0, result.Length - 2);
  finally
    LResult.Free;
  end;
end;

function TTDataFirebirdSQLSelectSyntax.GetSqlSyntax: String;
var
  LResult: TStringBuilder;
begin
  LResult := TStringBuilder.Create;
  try
    LResult.Append('SELECT ');
    if FFilter.Top.MaxRecord > 0 then
      LResult.AppendFormat('FIRST %d ', [FFilter.Top.MaxRecord]);
    LResult.Append(GetColumns());
    LResult.AppendFormat(' FROM %s', [FTableMap.Name]);
    if not FFilter.Where.IsEmpty then
      LResult.AppendFormat(' WHERE %s', [FFilter.Where]);
    LResult.Append(GetOrderBy());

    result := LResult.ToString();
  finally
    LResult.Free;
  end;
end;

{ TTDataFirebirdSQLMetadataSyntax }

constructor TTDataFirebirdSQLMetadataSyntax.Create(
  const AConnection: TFDConnection;
  const AMapper: TTMapper;
  const ATableMap: TTTableMap;
  const ATableMetadata: TTTableMetadata);
begin
  inherited Create(
    AConnection, AMapper, ATableMap, ATableMetadata, TTFilter.Create('0 = 1'));
end;

{ TTDataFirebirdSQLCommandSyntax }

constructor TTDataFirebirdSQLCommandSyntax.Create(
  const AConnection: TFDConnection;
  const AMapper: TTMapper;
  const ATableMap: TTTableMap;
  const ATableMetadata: TTTableMetadata);
begin
  inherited Create(AConnection, AMapper, ATableMap, ATableMetadata);
  FParameters := TObjectList<TTDataParameter>.Create(True);
end;

destructor TTDataFirebirdSQLCommandSyntax.Destroy;
begin
  FParameters.Free;
  inherited Destroy;
end;

procedure TTDataFirebirdSQLCommandSyntax.AfterConstruction;
begin
  CheckReadWrite;
  inherited AfterConstruction;
  InitializeParameters;
end;

procedure TTDataFirebirdSQLCommandSyntax.CheckReadWrite;
begin
  if (not Assigned(FTableMap.PrimaryKey)) or
    (not Assigned(FTableMap.VersionColumn)) then
    raise ETException.Create(SReadOnly);
end;

function TTDataFirebirdSQLCommandSyntax.GetColumnMap(
  const AColumnName: String): TTColumnMap;
var
  LColumn: TTColumnMap;
begin
  result := nil;
  for LColumn in FTableMap.Columns do
    if LColumn.Name.Equals(AColumnName) then
    begin
      result := LColumn;
      Break;
    end;

  if not Assigned(result) then
    raise ETException.CreateFmt(SColumnNotFound, [AColumnName]);
end;

procedure TTDataFirebirdSQLCommandSyntax.InitializeParameters;
var
  LColumn: TTColumnMetadata;
  LParam: TFDParam;
begin
  for LColumn in FTableMetadata.Columns do
  begin
    LParam := FDataset.Params.FindParam(LColumn.ColumnName);
    if Assigned(LParam) then
    begin
      LParam.ParamType := TParamType.ptInput;
      LParam.DataType := LColumn.DataType;
      LParam.Size := LColumn.DataSize;

      FParameters.Add(
        TTDataParameterFactory.Instance.CreateParameter(
          LColumn.DataType, LParam, FMapper, GetColumnMap(LColumn.ColumnName)));
    end;
  end;
end;

procedure TTDataFirebirdSQLCommandSyntax.AssignParameterValues(
  const AEntity: TObject);
var
  LParameter: TTDataParameter;
begin
  for LParameter in FParameters do
    LParameter.SetValue(AEntity);
end;

procedure TTDataFirebirdSQLCommandSyntax.BeforeExecute(
  const AEntity: TObject; const AEvent: TTEvent);
begin
  if Assigned(AEvent) then
    AEvent.DoBefore;
end;

procedure TTDataFirebirdSQLCommandSyntax.AfterExecute(
  const AEntity: TObject; const AEvent: TTEvent);
begin
  if Assigned(AEvent) then
    AEvent.DoAfter;
end;

procedure TTDataFirebirdSQLCommandSyntax.Execute(
  const AEntity: TObject; const AEvent: TTEvent);
var
  LLocalTransaction: Boolean;
begin
  LLocalTransaction := not FConnection.InTransaction;
  if LLocalTransaction then
    FConnection.StartTransaction;
  try
    BeforeExecute(AEntity, AEvent);

    AssignParameterValues(AEntity);
    FDataset.ExecSQL();
    if FDataset.RowsAffected = 0 then
      raise ETException.Create(SRecordChanged)
    else if FDataset.RowsAffected > 1 then
      raise ETException.Create(SSyntaxError);

    AfterExecute(AEntity, AEvent);

    if LLocalTransaction then
      FConnection.Commit;
  except
    if LLocalTransaction then
      FConnection.Rollback;
    raise;
  end;
end;

{ TTDataFirebirdSQLInsertSyntax }

function TTDataFirebirdSQLInsertSyntax.GetColumns: String;
var
  LResult: TStringBuilder;
  LColumnMap: TTColumnMap;
begin
  LResult := TStringBuilder.Create;
  try
    for LColumnMap in FTableMap.Columns do
      LResult.AppendFormat('%s, ', [LColumnMap.Name]);

    result := LResult.ToString();
    if not result.IsEmpty then
      result := result.Substring(0, result.Length - 2);
  finally
    LResult.Free;
  end;
end;

function TTDataFirebirdSQLInsertSyntax.GetParameters: String;
var
  LResult: TStringBuilder;
  LColumnMap: TTColumnMap;
begin
  LResult := TStringBuilder.Create;
  try
    for LColumnMap in FTableMap.Columns do
      if (LColumnMap <> FTableMap.VersionColumn) then
        LResult.AppendFormat(':%s, ', [LColumnMap.Name])
      else
        LResult.Append('0, ');

    result := LResult.ToString();
    result := result.SubString(0, result.Length - 2);
  finally
    LResult.Free;
  end;
end;

function TTDataFirebirdSQLInsertSyntax.GetSqlSyntax: String;
var
  LResult: TStringBuilder;
begin
  LResult := TStringBuilder.Create;
  try
    LResult.AppendFormat('INSERT INTO %s (', [FTableMap.Name]);
    LResult.Append(GetColumns());
    LResult.Append(') VALUES (');
    LResult.Append(GetParameters());
    LResult.Append(')');

    result := LResult.ToString();
  finally
    LResult.Free;
  end;
end;

{ TTDataFirebirdSQLUpdateSyntax }

function TTDataFirebirdSQLUpdateSyntax.GetColumns: String;
var
  LResult: TStringBuilder;
  LColumnMap: TTColumnMap;
begin
  LResult := TStringBuilder.Create;
  try
    for LColumnMap in FTableMap.Columns do
    begin
      if LColumnMap = FTableMap.PrimaryKey then
      else if LColumnMap = FTableMap.VersionColumn then
        LResult.AppendFormat('%0:s = %0:s + 1, ', [LColumnMap.Name])
      else
        LResult.AppendFormat('%0:s = :%0:s, ', [LColumnMap.Name])
    end;

    result := LResult.ToString();
    if not result.IsEmpty then
      result := result.Substring(0, result.Length - 2);
  finally
    LResult.Free;
  end;
end;

function TTDataFirebirdSQLUpdateSyntax.GetSqlSyntax: String;
var
  LResult: TStringBuilder;
begin
  LResult := TStringBuilder.Create;
  try
    LResult.AppendFormat('UPDATE %s SET ', [FTableMap.Name]);
    LResult.Append(GetColumns());
    LResult.AppendFormat(' WHERE %0:s = :%0:s AND %1:s = :%1:s', [
      FTableMap.PrimaryKey.Name, FTableMap.VersionColumn.Name]);

    result := LResult.ToString();
  finally
    LResult.Free;
  end;
end;

{ TTDataFirebirdSQLDeleteSyntax }

procedure TTDataFirebirdSQLDeleteSyntax.BeforeExecute(
  const AEntity: TObject; const AEvent: TTEvent);
var
  LID: TTPrimaryKey;
  LRelation: TTRelationMap;
  LDataset: TFDQuery;
begin
  inherited BeforeExecute(AEntity, AEvent);
  LID := FTableMap.PrimaryKey.Member.GetValue(AEntity).AsType<TTPrimaryKey>();
  for LRelation in FTableMap.Relations do
    if LRelation.IsCascade then
    begin
      LDataset := TFDQuery.Create(nil);
      try
        LDataset.Connection := FConnection;
        LDataset.ExecSQL(Format('DELETE FROM %0:s WHERE %1:s = %1:d', [
          LRelation.TableName, LRelation.ColumnName, LID]));
      finally
        LDataset.Free;
      end;
    end;
end;

function TTDataFirebirdSQLDeleteSyntax.GetSqlSyntax: String;
begin
  result := Format(
    'DELETE FROM %0:s WHERE %1:s = :%1:s AND %2:s = :%2:s', [
    FTableMap.Name, FTableMap.PrimaryKey.Name, FTableMap.VersionColumn.Name]);
end;

end.