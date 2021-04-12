## ISAPIGate - Http/Https gateway ISAPI

( ISAPI is a Microsoft specification for IIS native webserver applications ) 

# Description

This Delphi ISAPI implements a http/https gateway. It fetches files from 
remote web server(s) ( on a different host or on same host but different port ) 
and returns to the client. 

*ISAPIGate* is an old ISAPI application, from 2002, but is still useful.
Originally it was ported from a C sample, hence the C style.
It was writen before VCL's ISAPI. 

The remote server is selected according to a numeric ID in the query string.

example: 
  URL = https://www.myserver.com/scripts/ISAPIGate.dll/1/path?querystr
  In this example, server id='1' translates to '127.0.0.1:8080'  
  So file http://127.0.0.1:8080/path?querystr is returned.
  
ISAPIGate can route requests to multiple remote servers.
For security reasons, only registered servers are accepted.
The remote host table is *hard-coded* inside ISAPIGate.dpr.
To change the table, one has to edit and recompile ISAPIGate.dll.
This makes if more difficult for someone to hack the table, I suppose.  

Any kind of content can be routed: text, images, binary files.

In order to fetch a file, the 1st segment of the path is removed 
and the *path?querystr* is passed on to the remote host,
along with http request headers. 

For simplicity and safety, the remote host table is hard-coded
inside ISAPIGate.dpr source code. 

# ISAPIGate Uses 
* Route secure https requests to local http-only web server 
* Run web applications on separate web servers, while using the IIS server as a portal, sharing the server certificate. 
  
# IIS Configuration
There are some steps to configure IIS to run ISAPI scripts.
Those depend on IIS version. There are many tutorials on the internet on how to do that.

Basically you have to:

1- If running the remote server(s) on the same host as IIS, on a different port, 
remember to close that port for outside access on the firewall. 
Only allow access via ISAPIGate. 

2- Install IIS ISAPI support (not set by default )

3- On Internet Information Services Manager application :
    Select server > ISAPI and CGI Restrictions > Open Feature
    Add ISAPI extension:
       Description=ISAPIGate
       Restriction=Allowed
	   Path='c:\scripts_path\ISAPIGate.dll'  

4- Set IIS application poll to be reset periodically (p.e. daily) to avoid failure by heap fragmentation.


   

