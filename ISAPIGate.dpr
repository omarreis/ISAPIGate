library ISAPIGate; // Http Gateway via ISAPI  - ISAPIGate.dpr
 //--------------//
// project sources and docs: www.github.com/omarreis/ISAPIGate
// first version 2002
// dez18: ported p/ Delphi 10.3 Rio

{ Usage:
    https://www.tecepe.com.br/scripts/OpycGate.dll/1/path?queryst      ( 1 = host ID )
    maps to http://remoteserver:port/path?queryst

  Remote server(s) table hardcoded
}

uses
  Windows, Classes, SysUtils, Isapi2,
  HttpGateUtils;
  // Registry;  //obsolete use of the registry to specify remote servers

{$E dll}

{$R *.RES}

const
  Title='HttpGate';
  CRLF=#13#10;

  // administrative URLs - *change* this in your app !!
  AdmURLSalt='/HGsTasJhBfThjdlPPsdfdfgtrghhjwvjio';  //some "secret" protection to our adm URLs
  // '/HGsTasJhBfThjdlPPsdfdfgtrghhjwvjio/ISPIGateStatus'

var
  bShowURLs:boolean=FALSE;

Procedure ActivateShowURLs(aECB:PEXTENSION_CONTROL_BLOCK);
var S:AnsiString; L:dword;
begin
  bShowURLs := TRUE;
  S:='HTTP/1.0 200 OK'+CRLF+'Content-type: text/html'+CRLF+
     CRLF+
     '<html>Show URLs activated</html>';
  aECB.dwHttpStatusCode := 200;
  L := Length(S);
  aECB.WriteClient( aECB.ConnID, PAnsiChar(S), L, 0);
end;

// URI format:
//   RemoteHostID is the index of remote host
//   http://GatewayHost/scripts/ISAPIGate.dll/RemoteHostID/RemoteHostPath?RemoteHostQuery
//   this maps to  http://RemoteHost[:port]/RemoteHostPath?RemoteHostQuery
// The path:querystr part is copied

function GatewayHandleRequest(ECB:PEXTENSION_CONTROL_BLOCK):boolean;
var CliRequest,aHost,aPath,aQuery,S,StatusMessage:AnsiString;
    p,iPort,iHostID:integer; aHostID:ShortString;

begin   // get remote server:port
  Result:= FALSE;
  aPath := StrPas( ECB^.lpszPathInfo );
  //special adm "secret" urls
  if (aPath=AdmURLSalt+'/ISPIGateStatus') then    //show dll status
    begin
      Result := ShowISAPIGateStatus(ECB);
      exit;
    end;
  if (aPath=AdmURLSalt+'/ShowURLs') then          // obsolete
    begin
      ActivateShowURLs(ECB);
      Result := TRUE;
      exit;
    end;

  if (Length(aPath)<=2) then exit; //curto demais...
  Delete(aPath,1,1);               //apaga a 1a '/'
  p:=Pos('/',aPath);               //procura a 2a
  if p=0 then exit;                //nao tem a 2a '/' ! --> sai
  aHostID:=Copy(aPath,1,p-1);      //pega o HostID
  aPath:=Copy(aPath,p,200);        //remove o HostID do path que vai ser passado para o destino
  try iHostID:=StrToInt(aHostID); except exit; end;

  if (iHostID>0) and (iHostID<=NumAcceptedHosts) then // search host table.
    with AcceptedHosts[iHostID] do
      begin aHost:=Name; iPort:=Port; end             // host ID --> hostname
      else  exit;                                     //host id invalid, out

  //Host ok
  aQuery := StrPas( ECB^.lpszQueryString );
  if (aQuery<>'') then aPath:=aPath+'?'+aQuery;
  with ECB^ do
    begin
      CliRequest := StrPas(lpszMethod)+' '+aPath+' HTTP/1.1'+CRLF;
      //Add available headers to the request
      if GetClientHeader(ECB,'HTTP_ACCEPT',S)     then CliRequest:=CliRequest+'Accept: '+S+CRLF;
      if GetClientHeader(ECB,'HTTP_USER_AGENT',S) then CliRequest:=CliRequest+'User-Agent: '+S+CRLF;
      if GetClientHeader(ECB,'HTTP_IF_MODIFIED_SINCE',S) then CliRequest:=CliRequest+'If-Modified-Since: '+S+CRLF;
      if GetClientHeader(ECB,'HTTP_COOKIE',S)            then CliRequest:=CliRequest+'Cookie: '+S+CRLF;
      if GetClientHeader(ECB,'HTTP_AUTHORIZATION',S)     then CliRequest:=CliRequest+'Authorization: '+S+CRLF;
      if GetClientHeader(ECB,'CONTENT_TYPE',S)   then CliRequest:=CliRequest+'Content-Type: '+S+CRLF;
      if GetClientHeader(ECB,'CONTENT_LENGTH',S) then CliRequest:=CliRequest+'Content-Length: '+S+CRLF;
      if GetClientHeader(ECB,'HTTP_HOST',S)      then CliRequest:=CliRequest+'Host: '+S+CRLF;
      CliRequest:=CliRequest+CRLF;      // double crlf to finish header
      if (ECB^.cbAvailable>0) then
        begin
          SetString(S,PAnsiChar(ECB^.lpbData),ECB^.cbAvailable);
          CliRequest := CliRequest+S;
        end;
    end;

  if DoGatewayTransaction(aHost, CliRequest, iPort, ECB, StatusMessage)=0 then Result:=TRUE
    else begin
      StrPLCopy(ECB.lpszLogData, PAnsiChar(StatusMessage), HSE_LOG_BUFFER_LEN);
      Result := FALSE;  //no good..
    end;
end;

// read list of registered remotehost:port
Procedure ReadAcceptedHostsList;
// var Reg:TRegistry; Ok:Boolean; i,p:integer; aHost,aPort:String; iPort:integer;
begin
   // Hardcoded table of remote hosts
   NumAcceptedHosts := 1;   // 1 host

   // localhost:8080
   AcceptedHosts[1].Name  := '127.0.0.1';    //  AcceptedHosts[] 1 based
   AcceptedHosts[1].Port  := 8080;           //  same host, but port 8080

  // *obsolete* code to load host list from Windows registry
  // Reg := TRegistry.Create;
  // try
  //   Reg.RootKey:=HKEY_LOCAL_MACHINE;
  //   Ok:=Reg.OpenKey('Software\Enfoque\RioGate',FALSE);
  //   if Ok then for i:=1 to MaxAcceptedHosts do
  //     begin
  //       try aHost:=Reg.ReadString('Host'+IntToStr(i)); except exit; end;
  //       if aHost<>'' then
  //         begin
  //           p:=Pos(':',aHost);
  //           if p>0 then
  //             begin
  //               aPort:=Copy(aHost,p+1,MAXINT);
  //               try iPort:=StrToInt(aPort); except iPort:=80; end;
  //               aHost:=Copy(aHost,1,p-1);
  //             end
  //             else iPort:=80; //default port
  //           with AcceptedHosts[i] do begin Name:=aHost; Port:=iPort; end;
  //           NumAcceptedHosts:=i;
  //         end
  //         else exit; //host vazio, sai
  //     end;
  // finally
  //   Reg.Free;
  // end;

end;

{ exported fns  ---------------------------}

function HttpExtensionProc(var ECB: TEXTENSION_CONTROL_BLOCK): DWORD; stdcall;
begin
  try
    if GatewayHandleRequest(@ECB) then Result := HSE_STATUS_SUCCESS
      else Result := HSE_STATUS_ERROR;
  except
    Result := HSE_STATUS_ERROR;
  end;
end;

function GetExtensionVersion(var Ver: THSE_VERSION_INFO): BOOL;  stdcall;
begin
  try
    Ver.dwExtensionVersion := MakeLong(HSE_VERSION_MINOR, HSE_VERSION_MAJOR);
    StrLCopy( Ver.lpszExtensionDesc, PAnsiChar(Title), HSE_MAX_EXT_DLL_NAME_LEN);
    Result := True;
  except
    Result := False;
  end;
end;

function TerminateExtension(dwFlags: DWORD): BOOL; stdcall;
begin
  Result := True;
end;

exports
  GetExtensionVersion,
  HttpExtensionProc,
  TerminateExtension;

begin
  GateStartTime := now;
  ReadAcceptedHostsList;  //read list of registered remote hosts
end.

