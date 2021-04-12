# ISAPIGate - Http/Https gateway ISAPI

tl;dr - http/https gateway fetches files from external http-only webserver(s)

## Description

This Delphi ISAPI implements a http/https gateway. It fetches files from 
remote web server(s) (either on a different host or on same host but a different port ) 
and returns to the client. 

ISAPI is one of the first Microsoft specifications for IIS webserver applications.
The compiled executable is a native DLL that implements standard functions, 
called by IIS. Since it uses compiled code, ISAPI applications are efficient and safe.  

*ISAPIGate* is an old ISAPI application, from 2002, but is still useful.
Originally it was ported from a C sample, hence the C style.
It was writen before VCL's ISAPI, so it uses a custom ISAPI implementation. 

Another attribute of ISAPI applications: the API doesn't change, 
so it is rarely broken by changes   :)

## ISAPIGate uses 
* Route secure https requests to http-only web servers. 
* Run web applications on separate web servers while using the same IIS server as portal ( and sharing the SSL certificate ) 

More and more, secure https protocol is preferred over plaintext http for downloads. This is for security reasons.
Connetcion with a webserver with certified name is more reliable and safer to the user.
In some near future, mobile operating systems will only allow downloads using HTTPS.

The remote server is selected according to a numeric ID in the query string.

     example: 
     URL = https://www.myserver.com/scripts/ISAPIGate.dll/1/path?querystr
     In this example, server id='1' translates to '127.0.0.1:8080'  
     So file http://127.0.0.1:8080/path?querystr is returned.
  
ISAPIGate can route requests to multiple remote servers.
For security reasons, only registered servers are connected.

The remote host table is *hard-coded* inside ISAPIGate.dpr.
To change the table, one has to edit it and recompile ISAPIGate.dll.
This makes if more difficult for someone to hack the routing table, I suppose.

Note that changing ISAPIGate.dll requires stopping the server, so it is not for frequent changes.

Any kind of content can be routed: text, images, binary files.

In order to fetch a file, the 1st segment of the path is removed 
and the *path?querystr* is passed on to the remote host,
along with http request headers. 

## IIS Configuration
There are some steps to configure IIS to run ISAPI scripts.
Those depend on IIS version, so I will not go into details here. There are many tutorials on the internet, depending on your IIS and Windows vesrion.

Basically you have to:

1- If running the remote server(s) on the same host as IIS, on a different port, 
remember to close that port for outside access on the firewall. 
This way all access must go thru ISAPIGate. 

2- Install IIS ISAPI support (not set by default )

3- On Internet Information Services Manager application: 

      Select webserver, right-click and choose >Add Application
      Set application properties:
      Application pool=www.yourdomain.com
      Physical Path=c:\scripts_path\
      Preload Enabled=false
      Enabled protocols=http     (for http and https. If you want https only, set to https)

4- Allow ISAPI:

      Select server > ISAPI and CGI Restrictions > Open Feature
      Add ISAPI extension:
      Description=ISAPIGate
      Restriction=Allowed
      Path='c:\scripts_path\ISAPIGate.dll'  

5- Set IIS application pool to be reset periodically (p.e. daily) to avoid application failure by heap fragmentation.
   

  
