# ISAPIGate - Http/Https gateway ISAPI

tl;dr - http/https gateway serves files from local http-only webserver(s)

## Description

This Delphi ISAPI implements a http/https gateway.  

It fetches files from remote web server(s), either on a different host or a different port, and returns to the client. 

ISAPI is one of the first Microsoft specifications for IIS webserver applications.
The script executable is a native DLL that implements standard functions, 
called by IIS. Since it is pre-compiled, ISAPI applications are efficient and safe.  

*ISAPIGate* is from 2002, an old style but time proven ISAPI application.  
Originally it was ported from a C sample, hence the C style.
It is from before VCL's ISAPI support, so it uses a custom ISAPI implementation. 

Another attribute of ISAPI applications: the API doesn't change, 
so it is rarely broken   :)

## ISAPIGate uses 
* Route secure https requests to http-only web servers. 
* Run web applications on separate web servers while using the same IIS server as portal ( and sharing the SSL certificate ) 

Secure https protocol is preferred over plaintext http for downloads. 
Mobile operating systems recommend or require using https in apps.
Connections with a server with certified name are more reliable and safer.
But if you - like me - has a custom webserver that runs as a separate executable, 
chances are it does not support https transfers :(

## Routing files

With ISAPIGate, the remote server is selected using a numeric ID inside the URI.

     usage example: 
     URL = https://www.myserver.com/scripts/ISAPIGate.dll/1/path?querystr
     In this example, server id='/1' translates to '127.0.0.1:8080'  ( localhost )
     So file http://127.0.0.1:8080/path?querystr is returned.
  
ISAPIGate can route requests to multiple remote servers.

For security, only registered remote servers can be connected.
The remote server table is *hard-coded* inside ISAPIGate.dpr.
To change the table, edit source and recompile ISAPIGate.dll.
This makes if more difficult for someone to hack the routing table, I suppose.
Note that changing ISAPIGate.dll requires stopping the server, so it is not for frequent changes.

Any kind of content can be routed: text, images, binary files.

In order to fetch a file, the 1st segment of the path is removed 
and the *path?querystr* is passed on to the remote host,
along with http request headers. That includes cookies, authorization and other headers.  

Connection to the remote server uses old style sockets (WinSock).
Response is progressive, with bytes delivered as received.

Project is small: only 2 source files ISAPIGate.dpr and HttpGateUtils.pas   

*Current version was tested with Delphi 10.4.1, Windows Server 2016 and IIS 10.0
Compiled as a Win32 DLL ( must enable IIS Win32 ISAPIs )*

## ISAPIGate security

Note that ISAPIGate connects to the remote server(s) using an unencrypted socket. Security of the channel stops at this point. 

      <Internet> <-------http/https------> | <ISAPIGate> <------http-------> <remote server>    
                                           ^ firewall

Security tips:

* The remote server is supposed to be inside your network. 
* Don't gateway to servers over the internet. 
* Don't gateway to servers you don't control.

Configure the firewall to protect the channel from the jungle outside.

## IIS Configuration

There are some steps to configure Windows IIS to run ISAPI scripts.
Those depend on IIS version, so I will not go into details here. 
There are many tutorials on the internet, depending on IIS and Windows version.

Basically you have to:

1- If running the remote server(s) on the same host as IIS, but on a different port, 
remember to close that server port for outside access on the firewall. 
This way all outside access goes thru ISAPIGate.  

2- Install IIS ISAPI support if not installed by default.   

3- Create /scripts folder

      deploy c:\scripts_path\ISAPIGate.dll
      Open Internet Information Services Manager application:
      Select webserver main node, right-click >Add Application
      Set application properties:
        Virtual Path= /scripts
        Application pool= www.yourdomain.com
        Physical Path= c:\scripts_path\
        Preload Enabled= false
        Enabled protocols= http     (for http and https. If you want https only, set to https)

4- Enable 32-Bit ISAPI: 
 
      On Internet Information Services Manager application:
      Select Applications Pools
      Select www.yourdomain.com
      right-click and select Advanced Settings
      set Enable 32-bit Application to True  

5- Create ISAPIGate restriction:

      On Internet Information Services Manager application:
      Select server >ISAPI and CGI Restrictions>  click Open Feature
      Add ISAPI extension
        Description= ISAPIGate
        Restriction= Allowed
        Path= c:\scripts_path\ISAPIGate.dll  

6- Set IIS application pool to be reset periodically (p.e. daily) to avoid application failure by heap fragmentation.

