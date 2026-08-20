<!DOCTYPE html>
<html>
   <head>
      <title>$title</title>
      <style>
         @font-face{
         font-family: "Oranienbaum";
         src: url('res/Oranienbaum.ttf'),
         url('res/Oranienbaum.ttf'); /* IE */
         }
         html { height: 100%; }
         body {
         height: 100%;
         margin: 0 auto;
         font-family: Tahoma, Verdana, Arial, sans-serif;
         color: #535353;
         }
         #content {
         text-align: center;
         }
         #header {border-bottom: 1px solid grey;}
         h1 {
         font-family: "Oranienbaum";
         font-size: 2em;
         font-weight: normal;
         margin: 0px 10px 5px 20px;
         text-align: left;
         display: inline-block;
         }
         p {
         display: inline-block;
         margin: 0px 10px 5px 20px;
         }
         #links {text-align: center;}
         img.logo { height: 120px; opacity: .6; }
         img.logo:hover {opacity: 1;}
         img.disabled_logo {height: 120px; opacity: .1;}
         a.containerdiv { display: inline-block; text-decoration:initial; margin:30px;}
      </style>
   </head>
   <body>
      <div id = "header">
         <h1>$full_title</h1>
         <p>
            Development server.
         </p>
         <p>
           (This Server and this page have been created <a href="https://github.com/JeanLescutMuller/bootstrap-vm">from this project</a>, under Creative Common License. Free to use both personally and commercially, to be modified or shared. Only attribution rule should be respected. )
         </p>
      </div>
      <div id="content">
         <div id="links">
$links
         </div>
      </div>
   </body>
</html>
