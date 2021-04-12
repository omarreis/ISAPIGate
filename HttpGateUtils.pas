Unit HttpGateUtils;  // Utils de HttpGate.dll
 //-----------------//
// by omar reis 2002
// project sources and docs: www.github.com/omarreis/ISAPIGate
// dez18: ported from D7 to Delphi 10.3

interface

uses Windows, Classes, Isapi2, SysUtils, WinSock;

const
  VersionStr='ISAPIGate v1.5';         
  MaxAcceptedHosts=10;     // size of remote host table

var
  NumAcceptedHosts:integer=0;        //number of hosts read from registry
  HitsSinceLastStart:integer=0;     //hits since inicialization
  GateStartTime:TDateTime=0;       //dll startup tm

type
  THostHttpGate=record     // remote host record
    Name:AnsiString;
    Port:integer;
  end;

var // list of registered host/port
  AcceptedHosts:array[1..MaxAcceptedHosts] of THostHttpGate;

Function GetClientHeader(ECB:PEXTENSION_CONTROL_BLOCK; const Name:AnsiString; var Value:AnsiString):boolean;
Function DoGatewayTransaction(const Host,CliRequest:AnsiString; iPort:integer;  aECB:PEXTENSION_CONTROL_BLOCK; var StatusMessage:AnsiString):integer;
function ShowISAPIGateStatus(aECB:PEXTENSION_CONTROL_BLOCK):Boolean;

implementation

(* ServerVariables: array[0..28] of string = (
    '',
    'SERVER_PROTOCOL',
    'URL',
    '',
    '',
    '',
    'HTTP_CACHE_CONTROL',
    'HTTP_DATE',
    'HTTP_ACCEPT',
    'HTTP_FROM',
    'HTTP_HOST',
    'HTTP_IF_MODIFIED_SINCE',
    'HTTP_REFERER',
    'HTTP_USER_AGENT',
    'HTTP_CONTENT_ENCODING',
    'CONTENT_TYPE',
    'CONTENT_LENGTH',
    'HTTP_CONTENT_VERSION',
    'HTTP_DERIVED_FROM',
    'HTTP_EXPIRES',
    'HTTP_TITLE',
    'REMOTE_ADDR',
    'REMOTE_HOST',
    'SCRIPT_NAME',
    'SERVER_PORT',
    '',
    'HTTP_CONNECTION',
    'HTTP_COOKIE',
    'HTTP_AUTHORIZATION');
*)

Function GetClientHeader(ECB:PEXTENSION_CONTROL_BLOCK;const Name:AnsiString;var Value:AnsiString):boolean;
var Buffer:array[0..4095] of AnsiChar; Size: DWORD;
begin
  Size:=SizeOf(Buffer);
  if ECB.GetServerVariable(ECB.ConnID, PAnsiChar(Name), @Buffer, Size) then
  begin
    if Size>0 then Dec(Size);
    SetString(Value,Buffer,Size);
    Result:=(Value<>'');
  end
  else Result := FALSE;
end;

//-------------------------------------------------------------------------
//  recebe pelo socket sock até tamMax bytes no buffer apontado por buffer,
//  retorna numrecv se Ok,  e -1 no caso de erro
Function SockRecv(sock:TSocket;buffer:PAnsiChar;tamMax:integer):integer;
var numrecv:integer; 		// numero de bytes recebidos pelo recv()
begin
  numrecv:=recv(sock,buffer^,tamMax,0);
  if((numrecv=0) or (numrecv=SOCKET_ERROR)) then Result:=-1
    else  Result:=numrecv;
end;

//---------------------------------------------------------------
//  Returns 1 if Ok, 0 if error
//---------------------------------------------------------------
Function SockSend(sock:TSocket;buffer:PAnsiChar; tambuf:integer):integer;
var numsend:integer; bufptr:PAnsiChar; ix:integer;
begin
  ix:=0;
  bufptr:=buffer;
  while TRUE do
    begin
      if (tambuf<=0) then break;               //last block
      numsend := send(sock,bufptr^,tambuf,0);  //winsock send
      if ((numsend=0) or (numsend=SOCKET_ERROR)) then
        begin
          Result:=0;
          exit;
        end
	    else begin
	      dec(tambuf,numsend);
          inc(ix,numsend);
          bufptr := @buffer[ix];
	    end;
    end;
  Result:=1;
end;

//-------------------------------------------------------------------------
// Inputs:
//  Host= IP or server name ( IP addess preferred to avoid DNS search ) 
//  CliRequest = headers & client data, all in the same string
// Outputs:
//  0=ok, -1=erro. If error, StatusMessage returns description

Function DoGatewayTransaction(const Host,CliRequest:AnsiString; iPort:integer; aECB:PEXTENSION_CONTROL_BLOCK; var StatusMessage:AnsiString):integer;
var
  timeout_select:TTimeval;
  descritor:TFDSet;
  ssockopt:TLinger;
  SockRemoteSrv:TSocket;
  netaddr:dword;
  he:PHostEnt;
  conn_addr:TSockAddrIn;
  iret:integer;
  strBuffer:Array[0..1023] of AnsiChar;
  h_addr:PAnsiChar;
  L:integer;

begin
  inc(HitsSinceLastStart);     // should this be prottected by a CriticalSection ??
  StatusMessage:='';
  timeout_select.tv_sec := 10;
  timeout_select.tv_usec:= 0;
  ssockopt.l_onoff :=1;
  ssockopt.l_linger:=5000;
  //conecta com o servidor no destino
  SockRemoteSrv:=socket(PF_INET,SOCK_STREAM, 0);
  if (SockRemoteSrv=INVALID_SOCKET) then
    begin
      StatusMessage:='error creating socket to remote host';
      Result:=-1;
      exit;
    end;
  conn_addr.sin_family:=AF_INET;
  conn_addr.sin_port:=htons(iPort);   //porta no remoto
  netaddr:=inet_addr(PAnsiChar(Host));

  if (netaddr=INADDR_NONE) then    //nao conseguiu converter o endereco, entao passa para gethostbyname
    begin
      he:=gethostbyname(PAnsiChar(Host));
      if (he=Nil) then
        begin
          iret:=WSAGetLastError();
          StatusMessage:='Err: gethostbyname(): '+Host+' : '+IntToStr(iret);
          Result:=-1;
          exit;
        end;
      h_addr:=he^.h_addr_list^;
      conn_addr.sin_addr.S_un_b.s_b1 := h_addr[0]; {Copia os 4 bytes do IP}
      conn_addr.sin_addr.S_un_b.s_b2 := h_addr[1];
      conn_addr.sin_addr.S_un_b.s_b3 := h_addr[2];
      conn_addr.sin_addr.S_un_b.s_b4 := h_addr[3];
    end
    else conn_addr.sin_addr.S_addr:=netaddr; {especificou numero IP}
  FillChar(conn_addr.sin_zero,sizeof(conn_addr.sin_zero),#0);
  iret:=connect(SockRemoteSrv,conn_addr,sizeof(conn_addr));
  if (iret=SOCKET_ERROR) then
    begin
      StatusMessage:='Err: connect() to srv:'+IntToStr(WSAGetLastError);
      closesocket(SockRemoteSrv);
      Result:=-1;
      exit;   // fecha o socket e sai do thread
    end;
  //ok. connectado ao servidor
  ssockopt.l_onoff := 1;
  ssockopt.l_linger:=5000;
  iret:=setsockopt(SockRemoteSrv,SOL_SOCKET,SO_LINGER,PAnsiChar(@ssockopt),sizeof(ssockopt));
  if (iret=SOCKET_ERROR) then
    begin
      StatusMessage:='Err: setsockopt() :'+IntToStr(WSAGetLastError);
      closesocket (SockRemoteSrv);
      Result:=-1;
      exit;   // fecha o socket e sai do thread
    end;
  //conectado..
  L:=Length(CliRequest);
  if (L>0) then      // envia request do cliente para o srv remoto
    begin
      iret:=SockSend(SockRemoteSrv,PAnsiChar(CliRequest),L);
      if (iret<0) then
        begin
          StatusMessage:='Err: Send() to Srv: '+IntToStr(WSAGetLastError);
          closesocket (SockRemoteSrv);
          Result:=-1;
          exit;
        end;
    end;
  while TRUE do // exits only w/ break
    begin
      FD_ZERO( descritor );
      FD_SET(SockRemoteSrv, descritor);
      iret := select(1,@descritor,nil,nil,@timeout_select);
      if (iret<0) then
        begin
          StatusMessage:='Err: select() '+IntToStr(WSAGetLastError);
          break;
        end;
      if (iret=0) then continue;

      if (FD_ISSET(SockRemoteSrv, descritor)) then
        begin   //recv bytes from srv
          iret := SockRecv(SockRemoteSrv, strBuffer, sizeof(strBuffer));
          if (iret<0) then
            begin
              iret := WSAGetLastError();
              if (iret=WSAECONNRESET) then StatusMessage:='Err: Srv WSAECONNRESET'
                else if (iret<>0) then StatusMessage:='Err: recv() from Srv:'+IntToStr(iret);
              break;
            end;
          // else iret has number of bytes recvd
          if not aECB.WriteClient(aECB.ConnID,@strBuffer,DWORD(iret),0) then //send to client
            begin
              StatusMessage := 'Err: send() to Cli: '+IntToStr(WSAGetLastError);
              break;
            end;
        end; {if FD_ISSET}
    end; {while}
  // finished, gracefull termination of connection
  closesocket(SockRemoteSrv);
  Result:=0; //ok
end;

function ShowISAPIGateStatus(aECB:PEXTENSION_CONTROL_BLOCK):Boolean;
var aHS:THeapStatus; r1,r2:Double; S:AnsiString; L:Dword; i:integer;
const CRLF=#13#10;
begin
  aHS := GetHeapStatus;
  r1  := aHS.TotalAllocated;
  r2  := aHS.TotalFree;
  S:='HTTP/1.0 200 OK'+CRLF+
     'Content-type: text/html'+CRLF+  // two crlfs to separate http headers from content
     CRLF+
     '<html><h2>ISAPIGate status</h2><br>'+
     'ISAPIGate '+VersionStr+'<br>'+
     'Started: '+DateTimeToStr(GateStartTime)+'<br>'+
     'Running for '+Format('%6.1f',[Now-GateStartTime])+' days<br>'+
     'Hits since last start: '+IntToStr(HitsSinceLastStart)+'<br>'+
     'Memory:<br>'+
     ' - Total alloc: '+Format('%12.0n',[r1])+'<br>'+
     ' - Total free : '+Format('%12.0n',[r2])+'<br>';

  For i:=1 to NumAcceptedHosts do  //host list
    S := S+'Host '+IntToStr(i)+' - '+AcceptedHosts[i].Name+':'+IntToStr(AcceptedHosts[i].Port)+'<br>';

  S := S+'<br>https://github.com/omarreis/ISAPIGate<p></html>';

  aECB.dwHttpStatusCode := 200;
  L := Length(S);
  aECB.WriteClient(aECB.ConnID, PAnsiChar(S),L,0);
  Result:=TRUE;
end;

end.
