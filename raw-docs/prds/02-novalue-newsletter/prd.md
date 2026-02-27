# New Feature High Level
I need you to help me create a technical plan to implement a new feature. The new feature allows real estate agents to create email campaigns for recipients based only on:
client first_name
client last_name
client email
zip_code

Currently, newsletters requires the recipients address and property specific content. I'd like to provide agents the ability to market to people that either don't own a home, or where the agent doesnt know their address. This email should essentially be the same as the current newsletter, but without the Your Home section.

# More explanation on current newsletter
When an agent wants to create a new email campaign they enter the following information into a form and hit "Create Lead":
client first_name
client last_name
client email
property_address

The system starts by looking up their property by property_address on api-source-1 to determine its current value and purchase price.

Next the user provides the property address to api-source-2  which gathers a list of houses that have recently sold that are comps to their house, and gathers another list of similar houses for sale in their area.

Next the system asks an LLM to generate an intro paragraph and a paragraph responding to the increase or decrease in property value.

Once the system has gathered data from API sources, it builds an email. Here is the html of the email it sends:

<body class=3D"email-body" style=3D"font-family:Arial, Helvetica, sans-seri=
f; font-size:16px; line-height:1.4; color:#000; margin:0 !important; paddin=
g:0 !important; background-color:#f4f4f4; height:100% !important; width:100=
% !important" bgcolor=3D"#f4f4f4" height=3D"100% !important" width=3D"100% =
!important">
  <!--[if mso | IE]>
  <table role=3D"presentation" border=3D"0" cellpadding=3D"0" cellspacing=
=3D"0" width=3D"600" align=3D"center" style=3D"width:600px;">
    <tr>
      <td>
  <![endif]-->
 =20
  <center class=3D"email-container" style=3D"width:100%; background-color:#=
f4f4f4" width=3D"100%" bgcolor=3D"#f4f4f4">
    <div class=3D"email-wrapper" style=3D"width:100%; margin:0 auto; backgr=
ound-color:#fff" width=3D"100%" bgcolor=3D"#ffffff">
      <table cellpadding=3D"0" cellspacing=3D"0" border=3D"0" class=3D"main=
-table" role=3D"presentation" style=3D"width:100%; border-collapse:collapse=
 !important; margin:0 auto !important; background-color:#fff; mso-table-lsp=
ace:0 !important; mso-table-rspace:0 !important; border-spacing:0 !importan=
t; table-layout:fixed !important" width=3D"100%" bgcolor=3D"#ffffff">
       =20
        <!-- Your Home and Market Insights Banner -->
        <tr>
          <td class=3D"banner valign-top" style=3D"padding:18px 15px; line-=
height:22px; text-align:center; background-color:#e6f2f0; vertical-align:to=
p; mso-table-lspace:0 !important; mso-table-rspace:0 !important" align=3D"c=
enter" bgcolor=3D"#e6f2f0" valign=3D"top">
            <div class=3D"banner-text" style=3D"color:#004d40; font-size:20=
px; font-weight:bold; line-height:1.2; margin:0; padding:0">Your Real Estat=
e Market Update</div>
            <p class=3D"banner-subtext" style=3D"color:#555; font-size:14px=
; margin:10px 0 0 0">
              Here's a snapshot of your property value, local market activi=
ty, and trends.
            </p>           =20
          </td>
        </tr>

        <!-- Intro -->
        <tr>
          <td class=3D"content-section valign-top" style=3D"padding:18px 15=
px; line-height:22px; vertical-align:top; mso-table-lspace:0 !important; ms=
o-table-rspace:0 !important" valign=3D"top">
            <div>Hi Kenneth,</div>
            <div><br></div>
            <div>Hey! It's been way too long since we last connected. I hop=
e you and your family are doing well! I wanted to start sending you regular=
 updates about what's happening in your local real estate market - from you=
r home's current value to recent sales and market trends. If you ever want =
to chat about your home or have questions about any properties you see, jus=
t give me a shout!</div>
          </td>
        </tr>

        <!-- Signature -->
        <tr>
          <td class=3D"signature-container valign-top" style=3D"padding:18p=
x 15px; vertical-align:top; mso-table-lspace:0 !important; mso-table-rspace=
:0 !important" valign=3D"top">
            <table class=3D"signature-table" cellpadding=3D"0" cellspacing=
=3D"0" border=3D"0" style=3D"width:100%; border-spacing:0 !important; borde=
r-collapse:collapse !important; mso-table-lspace:0 !important; mso-table-rs=
pace:0 !important; table-layout:fixed !important; margin:0 auto !important"=
 width=3D"100%">
              <tr>
                <td class=3D"no-padding" style=3D"padding:0; margin:0; bord=
er-spacing:0; mso-table-lspace:0 !important; mso-table-rspace:0 !important"=
>
                  <table cellpadding=3D"0" cellspacing=3D"0" border=3D"0" c=
lass=3D"signature-inner-table" style=3D"width:100%; border-collapse:collaps=
e !important; border-spacing:0 !important; line-height:1.4; mso-table-lspac=
e:0 !important; mso-table-rspace:0 !important; table-layout:fixed !importan=
t; margin:0 auto !important" width=3D"100%">
                    <tr>
                      <td class=3D"signature-content-cell" style=3D"vertica=
l-align:top; padding-top:3px; mso-table-lspace:0 !important; mso-table-rspa=
ce:0 !important" valign=3D"top">
                        <p class=3D"signature-name" style=3D"margin:0 0 5px=
 0; padding:0; font-size:16px; font-weight:bold; color:#333; line-height:1.=
2">Kenny Huebsch</p>
                        <p class=3D"signature-contact" style=3D"margin:0 0 =
3px 0; padding:0; font-size:12px; color:#333; line-height:1.2">
                          <a href=3D"mailto:your.email@company.com" style=
=3D"color:#333; text-decoration:none">kenny@puffin.dev</a>
                        </p>
                        <div class=3D"signature-divider" style=3D"height:1p=
x; background-color:#ddd; margin:10px 0; font-size:0; line-height:0" height=
=3D"1" bgcolor=3D"#dddddd"></div>
                      </td>
                    </tr>
                  </table>
                </td>
              </tr>
            </table>
          </td>
        </tr>

        <!-- Your Home Banner-->
        <tr>
          <td class=3D"banner valign-top" style=3D"padding:18px 15px; line-=
height:22px; text-align:center; background-color:#e6f2f0; vertical-align:to=
p; mso-table-lspace:0 !important; mso-table-rspace:0 !important" align=3D"c=
enter" bgcolor=3D"#e6f2f0" valign=3D"top">
            <div class=3D"banner-text" style=3D"color:#004d40; font-size:20=
px; font-weight:bold; line-height:1.2; margin:0; padding:0">=F0=9F=8F=A1 Yo=
ur Home</div>
          </td>
        </tr>

        <!-- Your Home Image-->
        <tr>
          <td class=3D"image-section-no-padding valign-top align-center" st=
yle=3D"font-size:6px; line-height:10px; padding:0; text-align:center; verti=
cal-align:top; mso-table-lspace:0 !important; mso-table-rspace:0 !important=
" align=3D"center" valign=3D"top">
            <img border=3D"0" class=3D"full-width-image" width=3D"100%" alt=
=3D"" src=3D"https://photos.zillowstatic.com/fp/fc5ab1e58a61e8aa462ba56dc1f=
ab099-p_f.jpg" style=3D"border:0; outline:none; text-decoration:none; width=
:100%; height:auto; display:block" height=3D"auto">
          </td>
        </tr>

        <!-- Current Value-->
          <tr>
            <td class=3D"valign-top" style=3D"vertical-align:top; mso-table=
-lspace:0 !important; mso-table-rspace:0 !important" valign=3D"top">
              <table class=3D"main-table" cellpadding=3D"0" cellspacing=3D"=
0" border=3D"0" style=3D"width:100%; border-collapse:collapse !important; m=
argin:0 auto !important; background-color:#fff; mso-table-lspace:0 !importa=
nt; mso-table-rspace:0 !important; border-spacing:0 !important; table-layou=
t:fixed !important" width=3D"100%" bgcolor=3D"#ffffff">
                <tr>
                  <td class=3D"content-section-center valign-top" width=3D"=
50%" style=3D"padding:18px 15px; line-height:22px; text-align:center; verti=
cal-align:top; mso-table-lspace:0 !important; mso-table-rspace:0 !important=
; width:50%" align=3D"center" valign=3D"top">
                    <div><strong>Current Value</strong></div>
                    <div class=3D"large-text green-text" style=3D"font-size=
:18px; font-weight:bold; line-height:1.2; margin:0; color:#009688">$1,122,4=
54</div>
                  </td>
                  <td class=3D"content-section-center valign-top" width=3D"=
50%" style=3D"padding:18px 15px; line-height:22px; text-align:center; verti=
cal-align:top; mso-table-lspace:0 !important; mso-table-rspace:0 !important=
; width:50%" align=3D"center" valign=3D"top">
                    <div><strong>Since Purchase</strong></div>
                    <div class=3D"large-text green-text" style=3D"font-size=
:18px; font-weight:bold; line-height:1.2; margin:0; color:#009688">42.99%</=
div>
                  </td>
                </tr>
              </table>
            </td>
          </tr>         =20

        <!-- Home Report Analysis-->
        <tr>
          <td class=3D"content-section valign-top" style=3D"padding:18px 15=
px; line-height:22px; vertical-align:top; mso-table-lspace:0 !important; ms=
o-table-rspace:0 !important" valign=3D"top">
            <div>What an incredible investment you made! Your home has gain=
ed substantial value since your purchase, showing the strength of your loca=
l market and your smart buying decision. Of course, this is just an estimat=
e - if you'd like a more precise valuation or are curious about your option=
s, I'd love to chat!</div>
          </td>
        </tr>

        <!-- Your Market Banner -->
        <tr>
          <td class=3D"banner valign-top" style=3D"padding:18px 15px; line-=
height:22px; text-align:center; background-color:#e6f2f0; vertical-align:to=
p; mso-table-lspace:0 !important; mso-table-rspace:0 !important" align=3D"c=
enter" bgcolor=3D"#e6f2f0" valign=3D"top">
            <div class=3D"banner-text" style=3D"color:#004d40; font-size:20=
px; font-weight:bold; line-height:1.2; margin:0; padding:0">=F0=9F=93=88 Yo=
ur Market</div>
          </td>
        </tr>

        <!-- Local Trends -->
        <td class=3D"content-section" style=3D"padding:18px 20px; line-heig=
ht:22px; mso-table-lspace:0 !important; mso-table-rspace:0 !important">
          <h2 style=3D"margin:0 0 12px 0; font-size:16px; color:#004d40">Ma=
rket Changes in 18074 in the Last 3 Months</h2>

          <table width=3D"100%" cellpadding=3D"0" cellspacing=3D"0" style=
=3D"mso-table-lspace:0 !important; mso-table-rspace:0 !important; border-sp=
acing:0 !important; border-collapse:collapse !important; table-layout:fixed=
 !important; margin:0 auto !important; font-family:Arial, sans-serif; font-=
size:14px; color:#333">
            <tr>
              <td style=3D"mso-table-lspace:0 !important; mso-table-rspace:=
0 !important">Interest Rate:</td>
              <td align=3D"left" style=3D"mso-table-lspace:0 !important; ms=
o-table-rspace:0 !important"><strong>6.17%</strong>
                  <span class=3D"green-text" style=3D"color:#009688">(-8.46=
%)</span>
              </td>
            </tr>
            <tr>
              <td style=3D"mso-table-lspace:0 !important; mso-table-rspace:=
0 !important">Avg Home Price:</td>
              <td align=3D"left" style=3D"mso-table-lspace:0 !important; ms=
o-table-rspace:0 !important"><strong>$619,832</strong>
                  <span class=3D"red-text" style=3D"color:#f00">(-0.0%)</sp=
an>
              </td>
            </tr>
            <tr>
              <td style=3D"mso-table-lspace:0 !important; mso-table-rspace:=
0 !important">Avg Price per Sq Ft:</td>
              <td align=3D"left" style=3D"mso-table-lspace:0 !important; ms=
o-table-rspace:0 !important"><strong>$241.62</strong>
                  <span class=3D"green-text" style=3D"color:#009688">(=E2=
=87=A7 7.5%)</span>
              </td>
            </tr>
            <tr>
              <td style=3D"mso-table-lspace:0 !important; mso-table-rspace:=
0 !important">Active Listings:</td>
              <td align=3D"left" style=3D"mso-table-lspace:0 !important; ms=
o-table-rspace:0 !important"><strong>27</strong>
                  <span class=3D"green-text" style=3D"color:#009688">(-6.9%=
)</span>
              </td>
            </tr>
            <tr>
              <td style=3D"mso-table-lspace:0 !important; mso-table-rspace:=
0 !important">Avg Days on Market:</td>
              <td align=3D"left" style=3D"mso-table-lspace:0 !important; ms=
o-table-rspace:0 !important"><strong>49</strong>
                  <span class=3D"red-text" style=3D"color:#f00">(=E2=87=A7 =
43.0%)</span>
              </td>
            </tr>
          </table>
        </td>
     =20
        <!-- Most Expensive Listing In Your Area -->
        <tr>
          <td class=3D"content-section" style=3D"padding:18px 15px; line-he=
ight:22px; mso-table-lspace:0 !important; mso-table-rspace:0 !important">
            <h2 style=3D"margin:0 0 12px 0; font-size:16px; color:#004d40">=
Just For Fun... Most Expensive Listing In Your Area</h2>
          </td>
        </tr>
        <tr>
          <td class=3D"property-section valign-top" style=3D"padding:0 0; v=
ertical-align:top; mso-table-lspace:0 !important; mso-table-rspace:0 !impor=
tant" valign=3D"top">
            <table class=3D"property-table-left" cellpadding=3D"0" cellspac=
ing=3D"0" align=3D"center" border=3D"0" style=3D"width:100%; border-spacing=
:0 !important; border-collapse:collapse !important; margin:0 auto !importan=
t; padding:10px 0; text-align:center; mso-table-lspace:0 !important; mso-ta=
ble-rspace:0 !important; table-layout:fixed !important" width=3D"100%">
              <tr>
                <td class=3D"no-padding" style=3D"padding:0; margin:0; bord=
er-spacing:0; mso-table-lspace:0 !important; mso-table-rspace:0 !important"=
>
                  <img border=3D"0" class=3D"property-image" width=3D"100%"=
 alt=3D"" src=3D"https://photos.zillowstatic.com/fp/bc0c13baf50c4e4f06a0b86=
9c5e0a298-p_f.jpg" style=3D"border:0; outline:none; text-decoration:none; w=
idth:100%; height:auto; display:block" height=3D"auto">
                </td>
              </tr>
            </table>
            <table class=3D"property-table-right" cellpadding=3D"0" cellspa=
cing=3D"0" align=3D"center" border=3D"0" style=3D"width:100%; border-spacin=
g:0 !important; border-collapse:collapse !important; margin:0 auto !importa=
nt; padding:10px 0; text-align:center; mso-table-lspace:0 !important; mso-t=
able-rspace:0 !important; table-layout:fixed !important" width=3D"100%">
              <tr>
                <td class=3D"content-section valign-top" style=3D"padding:1=
8px 15px; line-height:22px; vertical-align:top; mso-table-lspace:0 !importa=
nt; mso-table-rspace:0 !important" valign=3D"top">
                  <div class=3D"address-text" style=3D"font-size:16px; line=
-height:1.3; margin:0 0 10px 0">2100 Fox Hollow Ln, Upper Hanover Township,=
 PA 18041</div>
                  <br>
                  Price: <strong>$1,650,000</strong><br>
                  Days on Market: <strong>59</strong>
                  <br><br>
                  <div><a href=3D"https://www.zillow.com/homedetails/100370=
56_zpid/">Link</a></div>
                </td>
              </tr>
            </table>
          </td>
        </tr>
       =20
        <!-- Recently Sold In Your Area Banner-->
        <tr>
          <td class=3D"banner valign-top" style=3D"padding:18px 15px; line-=
height:22px; text-align:center; background-color:#e6f2f0; vertical-align:to=
p; mso-table-lspace:0 !important; mso-table-rspace:0 !important" align=3D"c=
enter" bgcolor=3D"#e6f2f0" valign=3D"top">
            <div class=3D"banner-text" style=3D"color:#004d40; font-size:20=
px; font-weight:bold; line-height:1.2; margin:0; padding:0">=E2=9C=85 Recen=
tly Sold In Your Area</div>
          </td>
        </tr>

        <!-- Recent Sales-->
        <tr>
          <td class=3D"property-section valign-top" style=3D"padding:0 0; v=
ertical-align:top; mso-table-lspace:0 !important; mso-table-rspace:0 !impor=
tant" valign=3D"top">
            <table class=3D"property-listing-table-left" cellpadding=3D"0" =
cellspacing=3D"0" align=3D"center" border=3D"0" style=3D"width:100%; border=
-spacing:0 !important; border-collapse:collapse !important; margin:0 auto !=
important; padding:10px 0; text-align:center; mso-table-lspace:0 !important=
; mso-table-rspace:0 !important; table-layout:fixed !important" width=3D"10=
0%">
              <tr>
                <td class=3D"no-padding" style=3D"padding:0; margin:0; bord=
er-spacing:0; mso-table-lspace:0 !important; mso-table-rspace:0 !important"=
>
                  <img border=3D"0" class=3D"property-image" width=3D"100%"=
 alt=3D"" src=3D"https://photos.zillowstatic.com/fp/b82b3512997a5e6ea31d2bb=
4da1074e8-p_f.jpg" style=3D"border:0; outline:none; text-decoration:none; w=
idth:100%; height:auto; display:block" height=3D"auto">
                </td>
              </tr>
            </table>
            <table class=3D"property-listing-table-right" cellpadding=3D"0"=
 cellspacing=3D"0" align=3D"center" border=3D"0" style=3D"width:100%; borde=
r-spacing:0 !important; border-collapse:collapse !important; margin:0 auto =
!important; padding:10px 0; text-align:center; mso-table-lspace:0 !importan=
t; mso-table-rspace:0 !important; table-layout:fixed !important" width=3D"1=
00%">
              <tr>
                <td class=3D"content-section valign-top" style=3D"padding:1=
8px 15px; line-height:22px; vertical-align:top; mso-table-lspace:0 !importa=
nt; mso-table-rspace:0 !important" valign=3D"top">
                  <div class=3D"address-text" style=3D"font-size:16px; line=
-height:1.3; margin:0 0 10px 0">403 Washington Ave, Apt 3, Sellersville, PA=
 18960</div>
                  <br>
                  Price: <strong>$1,192,000</strong>
                  <br>
                  Sale Date: <strong>09-18-2025</strong>
                  <br><br>
                  <div><a href=3D"https://www.zillow.com/homedetails/205974=
7081_zpid/">Link</a></div>
                </td>
              </tr>
            </table>
          </td>
        </tr>
       =20
        <!-- Spacer -->
        <tr>
          <td class=3D"spacer valign-top" style=3D"padding:0; vertical-alig=
n:top; mso-table-lspace:0 !important; mso-table-rspace:0 !important" valign=
=3D"top">
            <table border=3D"0" cellpadding=3D"0" cellspacing=3D"0" align=
=3D"center" class=3D"spacer-table" style=3D"border:0; line-height:3px; font=
-size:3px; width:100%; height:3px; mso-table-lspace:0 !important; mso-table=
-rspace:0 !important; border-spacing:0 !important; border-collapse:collapse=
 !important; table-layout:fixed !important; margin:0 auto !important" width=
=3D"100%" height=3D"3">
              <tr>
                <td class=3D"spacer-cell" style=3D"padding:0 0 3px 0; backg=
round-color:#e6f2f0; mso-table-lspace:0 !important; mso-table-rspace:0 !imp=
ortant" bgcolor=3D"#e6f2f0"></td>
              </tr>
            </table>
          </td>
        </tr>
        <tr>
          <td class=3D"property-section valign-top" style=3D"padding:0 0; v=
ertical-align:top; mso-table-lspace:0 !important; mso-table-rspace:0 !impor=
tant" valign=3D"top">
            <table class=3D"property-listing-table-left" cellpadding=3D"0" =
cellspacing=3D"0" align=3D"center" border=3D"0" style=3D"width:100%; border=
-spacing:0 !important; border-collapse:collapse !important; margin:0 auto !=
important; padding:10px 0; text-align:center; mso-table-lspace:0 !important=
; mso-table-rspace:0 !important; table-layout:fixed !important" width=3D"10=
0%">
              <tr>
                <td class=3D"no-padding" style=3D"padding:0; margin:0; bord=
er-spacing:0; mso-table-lspace:0 !important; mso-table-rspace:0 !important"=
>
                  <img border=3D"0" class=3D"property-image" width=3D"100%"=
 alt=3D"" src=3D"https://photos.zillowstatic.com/fp/e54399b22e1e9c4cd708e0a=
0e54e460f-p_f.jpg" style=3D"border:0; outline:none; text-decoration:none; w=
idth:100%; height:auto; display:block" height=3D"auto">
                </td>
              </tr>
            </table>
            <table class=3D"property-listing-table-right" cellpadding=3D"0"=
 cellspacing=3D"0" align=3D"center" border=3D"0" style=3D"width:100%; borde=
r-spacing:0 !important; border-collapse:collapse !important; margin:0 auto =
!important; padding:10px 0; text-align:center; mso-table-lspace:0 !importan=
t; mso-table-rspace:0 !important; table-layout:fixed !important" width=3D"1=
00%">
              <tr>
                <td class=3D"content-section valign-top" style=3D"padding:1=
8px 15px; line-height:22px; vertical-align:top; mso-table-lspace:0 !importa=
nt; mso-table-rspace:0 !important" valign=3D"top">
                  <div class=3D"address-text" style=3D"font-size:16px; line=
-height:1.3; margin:0 0 10px 0">1625 Canary Rd, Quakertown, PA 18951</div>
                  <br>
                  Price: <strong>$330,000</strong>
                  <br>
                  Sale Date: <strong>08-06-2025</strong>
                  <br><br>
                  <div><a href=3D"https://www.zillow.com/homedetails/904565=
7_zpid/">Link</a></div>
                </td>
              </tr>
            </table>
          </td>
        </tr>
       =20
        <!-- Spacer -->
        <tr>
          <td class=3D"spacer valign-top" style=3D"padding:0; vertical-alig=
n:top; mso-table-lspace:0 !important; mso-table-rspace:0 !important" valign=
=3D"top">
            <table border=3D"0" cellpadding=3D"0" cellspacing=3D"0" align=
=3D"center" class=3D"spacer-table" style=3D"border:0; line-height:3px; font=
-size:3px; width:100%; height:3px; mso-table-lspace:0 !important; mso-table=
-rspace:0 !important; border-spacing:0 !important; border-collapse:collapse=
 !important; table-layout:fixed !important; margin:0 auto !important" width=
=3D"100%" height=3D"3">
              <tr>
                <td class=3D"spacer-cell" style=3D"padding:0 0 3px 0; backg=
round-color:#e6f2f0; mso-table-lspace:0 !important; mso-table-rspace:0 !imp=
ortant" bgcolor=3D"#e6f2f0"></td>
              </tr>
            </table>
          </td>
        </tr>
        <tr>
          <td class=3D"property-section valign-top" style=3D"padding:0 0; v=
ertical-align:top; mso-table-lspace:0 !important; mso-table-rspace:0 !impor=
tant" valign=3D"top">
            <table class=3D"property-listing-table-left" cellpadding=3D"0" =
cellspacing=3D"0" align=3D"center" border=3D"0" style=3D"width:100%; border=
-spacing:0 !important; border-collapse:collapse !important; margin:0 auto !=
important; padding:10px 0; text-align:center; mso-table-lspace:0 !important=
; mso-table-rspace:0 !important; table-layout:fixed !important" width=3D"10=
0%">
              <tr>
                <td class=3D"no-padding" style=3D"padding:0; margin:0; bord=
er-spacing:0; mso-table-lspace:0 !important; mso-table-rspace:0 !important"=
>
                  <img border=3D"0" class=3D"property-image" width=3D"100%"=
 alt=3D"" src=3D"https://photos.zillowstatic.com/fp/36b2dca076380558830ca7d=
5c2129975-p_f.jpg" style=3D"border:0; outline:none; text-decoration:none; w=
idth:100%; height:auto; display:block" height=3D"auto">
                </td>
              </tr>
            </table>
            <table class=3D"property-listing-table-right" cellpadding=3D"0"=
 cellspacing=3D"0" align=3D"center" border=3D"0" style=3D"width:100%; borde=
r-spacing:0 !important; border-collapse:collapse !important; margin:0 auto =
!important; padding:10px 0; text-align:center; mso-table-lspace:0 !importan=
t; mso-table-rspace:0 !important; table-layout:fixed !important" width=3D"1=
00%">
              <tr>
                <td class=3D"content-section valign-top" style=3D"padding:1=
8px 15px; line-height:22px; vertical-align:top; mso-table-lspace:0 !importa=
nt; mso-table-rspace:0 !important" valign=3D"top">
                  <div class=3D"address-text" style=3D"font-size:16px; line=
-height:1.3; margin:0 0 10px 0">164 Birdsong Way, Pottstown, PA 19464</div>
                  <br>
                  Price: <strong>$195,000</strong>
                  <br>
                  Sale Date: <strong>09-10-2025</strong>
                  <br><br>
                  <div><a href=3D"https://www.zillow.com/homedetails/100540=
44_zpid/">Link</a></div>
                </td>
              </tr>
            </table>
          </td>
        </tr>
       =20
        <!-- Spacer -->
        <tr>
          <td class=3D"spacer valign-top" style=3D"padding:0; vertical-alig=
n:top; mso-table-lspace:0 !important; mso-table-rspace:0 !important" valign=
=3D"top">
            <table border=3D"0" cellpadding=3D"0" cellspacing=3D"0" align=
=3D"center" class=3D"spacer-table" style=3D"border:0; line-height:3px; font=
-size:3px; width:100%; height:3px; mso-table-lspace:0 !important; mso-table=
-rspace:0 !important; border-spacing:0 !important; border-collapse:collapse=
 !important; table-layout:fixed !important; margin:0 auto !important" width=
=3D"100%" height=3D"3">
              <tr>
                <td class=3D"spacer-cell" style=3D"padding:0 0 3px 0; backg=
round-color:#e6f2f0; mso-table-lspace:0 !important; mso-table-rspace:0 !imp=
ortant" bgcolor=3D"#e6f2f0"></td>
              </tr>
            </table>
          </td>
        </tr>

        <!-- For Sale In Your Area Title-->
        <tr>
          <td class=3D"banner valign-top" style=3D"padding:18px 15px; line-=
height:22px; text-align:center; background-color:#e6f2f0; vertical-align:to=
p; mso-table-lspace:0 !important; mso-table-rspace:0 !important" align=3D"c=
enter" bgcolor=3D"#e6f2f0" valign=3D"top">
            <div class=3D"banner-text" style=3D"color:#004d40; font-size:20=
px; font-weight:bold; line-height:1.2; margin:0; padding:0">=F0=9F=94=8D Fo=
r Sale In Your Area</div>
          </td>
        </tr>

        <!-- For Sale -->
        <tr>
          <td class=3D"property-section valign-top" style=3D"padding:0 0; v=
ertical-align:top; mso-table-lspace:0 !important; mso-table-rspace:0 !impor=
tant" valign=3D"top">
            <table class=3D"property-listing-table-left" cellpadding=3D"0" =
cellspacing=3D"0" align=3D"center" border=3D"0" style=3D"width:100%; border=
-spacing:0 !important; border-collapse:collapse !important; margin:0 auto !=
important; padding:10px 0; text-align:center; mso-table-lspace:0 !important=
; mso-table-rspace:0 !important; table-layout:fixed !important" width=3D"10=
0%">
              <tr>
                <td class=3D"no-padding" style=3D"padding:0; margin:0; bord=
er-spacing:0; mso-table-lspace:0 !important; mso-table-rspace:0 !important"=
>
                  <img border=3D"0" class=3D"property-image" width=3D"100%"=
 alt=3D"" src=3D"https://photos.zillowstatic.com/fp/0f661e6905aec759bd88d11=
8ea728197-p_f.jpg" style=3D"border:0; outline:none; text-decoration:none; w=
idth:100%; height:auto; display:block" height=3D"auto">
                </td>
              </tr>
            </table>
            <table class=3D"property-listing-table-right" cellpadding=3D"0"=
 cellspacing=3D"0" align=3D"center" border=3D"0" style=3D"width:100%; borde=
r-spacing:0 !important; border-collapse:collapse !important; margin:0 auto =
!important; padding:10px 0; text-align:center; mso-table-lspace:0 !importan=
t; mso-table-rspace:0 !important; table-layout:fixed !important" width=3D"1=
00%">
              <tr>
                <td class=3D"content-section valign-top" style=3D"padding:1=
8px 15px; line-height:22px; vertical-align:top; mso-table-lspace:0 !importa=
nt; mso-table-rspace:0 !important" valign=3D"top">
                  <div class=3D"address-text" style=3D"font-size:16px; line=
-height:1.3; margin:0 0 10px 0">624 Crestwood Dr, Telford, PA 18969</div>
                  <br>
                  Price: <strong>$1,189,000</strong><br>
                  Days on Market: <strong>5</strong>
                  <br><br>
                  <div><a href=3D"https://www.zillow.com/homedetails/170128=
161_zpid/">Link</a></div>
                </td>
              </tr>
            </table>
          </td>
        </tr>

        <!-- Spacer -->
        <tr>
          <td class=3D"spacer valign-top" style=3D"padding:0; vertical-alig=
n:top; mso-table-lspace:0 !important; mso-table-rspace:0 !important" valign=
=3D"top">
            <table border=3D"0" cellpadding=3D"0" cellspacing=3D"0" align=
=3D"center" class=3D"spacer-table" style=3D"border:0; line-height:3px; font=
-size:3px; width:100%; height:3px; mso-table-lspace:0 !important; mso-table=
-rspace:0 !important; border-spacing:0 !important; border-collapse:collapse=
 !important; table-layout:fixed !important; margin:0 auto !important" width=
=3D"100%" height=3D"3">
              <tr>
                <td class=3D"spacer-cell" style=3D"padding:0 0 3px 0; backg=
round-color:#e6f2f0; mso-table-lspace:0 !important; mso-table-rspace:0 !imp=
ortant" bgcolor=3D"#e6f2f0"></td>
              </tr>
            </table>
          </td>
        </tr>
        <tr>
          <td class=3D"property-section valign-top" style=3D"padding:0 0; v=
ertical-align:top; mso-table-lspace:0 !important; mso-table-rspace:0 !impor=
tant" valign=3D"top">
            <table class=3D"property-listing-table-left" cellpadding=3D"0" =
cellspacing=3D"0" align=3D"center" border=3D"0" style=3D"width:100%; border=
-spacing:0 !important; border-collapse:collapse !important; margin:0 auto !=
important; padding:10px 0; text-align:center; mso-table-lspace:0 !important=
; mso-table-rspace:0 !important; table-layout:fixed !important" width=3D"10=
0%">
              <tr>
                <td class=3D"no-padding" style=3D"padding:0; margin:0; bord=
er-spacing:0; mso-table-lspace:0 !important; mso-table-rspace:0 !important"=
>
                  <img border=3D"0" class=3D"property-image" width=3D"100%"=
 alt=3D"" src=3D"https://photos.zillowstatic.com/fp/62051afd9cfd8fd90422457=
fc8f60570-p_f.jpg" style=3D"border:0; outline:none; text-decoration:none; w=
idth:100%; height:auto; display:block" height=3D"auto">
                </td>
              </tr>
            </table>
            <table class=3D"property-listing-table-right" cellpadding=3D"0"=
 cellspacing=3D"0" align=3D"center" border=3D"0" style=3D"width:100%; borde=
r-spacing:0 !important; border-collapse:collapse !important; margin:0 auto =
!important; padding:10px 0; text-align:center; mso-table-lspace:0 !importan=
t; mso-table-rspace:0 !important; table-layout:fixed !important" width=3D"1=
00%">
              <tr>
                <td class=3D"content-section valign-top" style=3D"padding:1=
8px 15px; line-height:22px; vertical-align:top; mso-table-lspace:0 !importa=
nt; mso-table-rspace:0 !important" valign=3D"top">
                  <div class=3D"address-text" style=3D"font-size:16px; line=
-height:1.3; margin:0 0 10px 0">224 Orchard Ln, Harleysville, PA 19438</div=
>
                  <br>
                  Price: <strong>$1,049,000</strong><br>
                  Days on Market: <strong>5</strong>
                  <br><br>
                  <div><a href=3D"https://www.zillow.com/homedetails/100064=
99_zpid/">Link</a></div>
                </td>
              </tr>
            </table>
          </td>
        </tr>

        <!-- Spacer -->
        <tr>
          <td class=3D"spacer valign-top" style=3D"padding:0; vertical-alig=
n:top; mso-table-lspace:0 !important; mso-table-rspace:0 !important" valign=
=3D"top">
            <table border=3D"0" cellpadding=3D"0" cellspacing=3D"0" align=
=3D"center" class=3D"spacer-table" style=3D"border:0; line-height:3px; font=
-size:3px; width:100%; height:3px; mso-table-lspace:0 !important; mso-table=
-rspace:0 !important; border-spacing:0 !important; border-collapse:collapse=
 !important; table-layout:fixed !important; margin:0 auto !important" width=
=3D"100%" height=3D"3">
              <tr>
                <td class=3D"spacer-cell" style=3D"padding:0 0 3px 0; backg=
round-color:#e6f2f0; mso-table-lspace:0 !important; mso-table-rspace:0 !imp=
ortant" bgcolor=3D"#e6f2f0"></td>
              </tr>
            </table>
          </td>
        </tr>
        <tr>
          <td class=3D"property-section valign-top" style=3D"padding:0 0; v=
ertical-align:top; mso-table-lspace:0 !important; mso-table-rspace:0 !impor=
tant" valign=3D"top">
            <table class=3D"property-listing-table-left" cellpadding=3D"0" =
cellspacing=3D"0" align=3D"center" border=3D"0" style=3D"width:100%; border=
-spacing:0 !important; border-collapse:collapse !important; margin:0 auto !=
important; padding:10px 0; text-align:center; mso-table-lspace:0 !important=
; mso-table-rspace:0 !important; table-layout:fixed !important" width=3D"10=
0%">
              <tr>
                <td class=3D"no-padding" style=3D"padding:0; margin:0; bord=
er-spacing:0; mso-table-lspace:0 !important; mso-table-rspace:0 !important"=
>
                  <img border=3D"0" class=3D"property-image" width=3D"100%"=
 alt=3D"" src=3D"https://photos.zillowstatic.com/fp/ce2319207cc670dd541782a=
89a029e97-p_f.jpg" style=3D"border:0; outline:none; text-decoration:none; w=
idth:100%; height:auto; display:block" height=3D"auto">
                </td>
              </tr>
            </table>
            <table class=3D"property-listing-table-right" cellpadding=3D"0"=
 cellspacing=3D"0" align=3D"center" border=3D"0" style=3D"width:100%; borde=
r-spacing:0 !important; border-collapse:collapse !important; margin:0 auto =
!important; padding:10px 0; text-align:center; mso-table-lspace:0 !importan=
t; mso-table-rspace:0 !important; table-layout:fixed !important" width=3D"1=
00%">
              <tr>
                <td class=3D"content-section valign-top" style=3D"padding:1=
8px 15px; line-height:22px; vertical-align:top; mso-table-lspace:0 !importa=
nt; mso-table-rspace:0 !important" valign=3D"top">
                  <div class=3D"address-text" style=3D"font-size:16px; line=
-height:1.3; margin:0 0 10px 0">111 Mine Run Rd, Schwenksville, PA 19473</d=
iv>
                  <br>
                  Price: <strong>$1,100,000</strong><br>
                  Days on Market: <strong>7</strong>
                  <br><br>
                  <div><a href=3D"https://www.zillow.com/homedetails/994406=
6_zpid/">Link</a></div>
                </td>
              </tr>
            </table>
          </td>
        </tr>

        <!-- Spacer -->
        <tr>
          <td class=3D"spacer valign-top" style=3D"padding:0; vertical-alig=
n:top; mso-table-lspace:0 !important; mso-table-rspace:0 !important" valign=
=3D"top">
            <table border=3D"0" cellpadding=3D"0" cellspacing=3D"0" align=
=3D"center" class=3D"spacer-table" style=3D"border:0; line-height:3px; font=
-size:3px; width:100%; height:3px; mso-table-lspace:0 !important; mso-table=
-rspace:0 !important; border-spacing:0 !important; border-collapse:collapse=
 !important; table-layout:fixed !important; margin:0 auto !important" width=
=3D"100%" height=3D"3">
              <tr>
                <td class=3D"spacer-cell" style=3D"padding:0 0 3px 0; backg=
round-color:#e6f2f0; mso-table-lspace:0 !important; mso-table-rspace:0 !imp=
ortant" bgcolor=3D"#e6f2f0"></td>
              </tr>
            </table>
          </td>
        </tr>

        <!-- Quick Tips Banner-->
        <tr>
          <td class=3D"banner valign-top" style=3D"padding:18px 15px; line-=
height:22px; text-align:center; background-color:#e6f2f0; vertical-align:to=
p; mso-table-lspace:0 !important; mso-table-rspace:0 !important" align=3D"c=
enter" bgcolor=3D"#e6f2f0" valign=3D"top">
            <div class=3D"banner-text" style=3D"color:#004d40; font-size:20=
px; font-weight:bold; line-height:1.2; margin:0; padding:0">=F0=9F=92=A1 Qu=
ick Tips</div>
          </td>
        </tr>

        <!-- Education Topic Image -->
        <tr>
          <td class=3D"image-section-no-padding valign-top align-center" st=
yle=3D"font-size:6px; line-height:10px; padding:0; text-align:center; verti=
cal-align:top; mso-table-lspace:0 !important; mso-table-rspace:0 !important=
" align=3D"center" valign=3D"top">
            <img border=3D"0" class=3D"full-width-image" width=3D"100%" alt=
=3D"" src=3D"https://dripr-prod.s3.us-east-1.amazonaws.com/education-topic-=
images/how-much-can-i-afford.png" style=3D"border:0; outline:none; text-dec=
oration:none; width:100%; height:auto; display:block" height=3D"auto">
          </td>
        </tr>

        <!-- Education Topic Title and Content -->
        <tr>
          <td class=3D"content-section valign-top" style=3D"padding:18px 15=
px; line-height:22px; vertical-align:top; mso-table-lspace:0 !important; ms=
o-table-rspace:0 !important" valign=3D"top">
            <h2 style=3D"margin:0 0 12px 0; font-size:16px; color:#004d40">=
How Much Can I Afford?</h2>
            <div>When you=E2=80=99re figuring out how much home you can aff=
ord, a good rule of thumb is the 28/36 rule =E2=80=94 try to keep your hous=
ing costs under about 28% of your gross income, and all your monthly debts =
under 36%. Lenders will also look at your debt-to-income ratio, income stab=
ility, and how much you=E2=80=99re putting down. It=E2=80=99s all about fin=
ding that sweet spot where your dream home fits comfortably within your bud=
get.</div>
          </td>
        </tr>
      </table>
    </div>
  </center>
 =20
  <!--[if mso | IE]>
      </td>
    </tr>
  </table>
  <![endif]-->
<p style=3D"text-align:center;margin:1em 0 3em;"><a href=3D"https://subscri=
ptions.pstmrk.it/unsubscribe?m=3D1.zjl0X4U29vQlV4Qks64Exg.i9L53KhOeRtT-R0IL=
KiGykOvuGlE8SwybAUJ9j-tea_kWstQ4LJPwqQlTxAcRoZDE69zFZX5mhlPG2rf6rM48wS4pr4h=
RKXuji9fHMu3TxUQOmycD6Ncmf8fNwI17qm-Tzl5wMNdI6ESFEdxli57jvH_g_orNlhv3GKIdc1=
x5_NT94Ox-VCtksCofElsX7evbDlmB1sNv2XohGc29ClmT5goEw2kNbH2EvZxBelC5UotNm5H5L=
_CQAuwR9ljlSMLqM703kx7wS0JIuJZw2TxMsxTHbHNi4T46-1tlkvF3XiS_lOVOnR3mW1ZE5d44=
y2KQIVQHgUICdT3GPJEYYSxky__OI-uYkJJFYDkBFGhdECPBOPN6tmXRBgJiKs3SiPUvVBrHZOJ=
0JRd9WrWmCjtylXoRAL2I3NuLhpE78eG0G3GAhe-b-SCBGeUvrj0_ITHExNjFpUgjzGaX9C6BlC=
qedG2pbqnpMyPlMcDeCzDV783Ea9DNkC_2npAemgxOxDnoiLyCv9XvO-Zw4LjOOAvkaqGFelAX_=
FYexvsVQ9HccJZTO-Zlo_IDICXCNIfMiZ4VMAmd5LR6XW9iHam-2T2kDpHDGcTb0AP_GLi3Otff=
VMQ96pG5qeSTRIKR9HkHkIEyii2Fz6EQNtND-_ydlhBQo67uFalokL_9D_bvuz1_KEx-bGbnuk7=
Ym8Jp8GH_Ju_-H-H4GsMy3r5YPvTZ3JhLA" style=3D"color:#A8AAAF;font-family:Helv=
etica,Arial,sans-serif;font-size:12px;">Unsubscribe</a></p><img src=3D"http=
s://ea.pstmrk.it/open?m=3Dv3_1.gt8B4-sn1GxsLD6-br2JOQ.YECnTsug3cr26sf2L6dJh=
h7OrkYY0UildfTFSoOn2YclR_l3MxdRFPeRyBpnjSvbQLDKHw-YCfMPC2-xRx3bclLHyTBvbt32=
t1bvmvJjcx_GjBPBwCZPoth0SJWi0_P7t53KOO2u3vHw9cV1GpRbRahOhpobhCZ3CR6VGRunsga=
hlF5AG7tBXQtMYWx0dowR2khAInmjxemrhkpHlED05SMmBX8jW5T4dhY8XlH0MBTzHE0pc9qK0Q=
vT7nhxqvaXa8XEeM0S9w7hkzQI2kLFPK_FJeWGjkA6kGgKMAJwlKx0juZty6Js_55BHDLMxaTF0=
e-E2PktU3frNZdvyanEajcC5UvR6DfYT5Ii5hD1LDzNP7-UU02uJF7TjQZnzIeFxSsH5pgIJijV=
UgIFxyGvvId7LB0ZNd4Jc0d_RYPYp3krF2sHTYnlkoGgQSJCErX88uBn9O2glpYMGU5lK1jzvzf=
AWOcxX7fCvzJL98wXjF5YqbVQ4FVRol8vVmCkVPfTPEsCEkBSjTaS-V9syBrXpzbIkgBLRZcGzI=
bbVkJdnKo87YsTU9rZm_7tkPa0a6JHM50XFEcxYamzgBWhQYfnAxKyZb1pRMWIht5TtiWLvU6nR=
IbmPgmHFX7AH78eIstJBzcgoy8WI7gUVGRKwBcwFcUAPAcMM0lz41TgmzNTOTBKZR4znies9367=
ivI9puEB5IsFGVHaSvnWQwu4vOzSjKB41fCIzCHHr_PV5NMVwHA" width=3D"1" height=3D"=
1" border=3D"0" alt=3D"" /></body>


# Functional Requirements
- When creating a new campaign, there should be a toggle on the Create New Campaign Form to indicate whether this newsletter contains home valuation.
- If the user toggles home valuation off, then the property address section of the Create New Campaign Form should disappear and a zip code input field should appear
- The user must manually enter a zip_code when home valuation is toggled off
- When the system is gathering data from the Rentcast api (D:\Repositories\dripr\python\shared_resources\rentcast_api_client.py), it should use the zip_code to query for homes. Use Rentcast API for both "Recently Sold" and "For Sale" sections (this is current behavior). Here is a link to the api https://developers.rentcast.io/reference/introduction
- The system should sort results by how new they are. newest are highest priority. After that the system should follow the same logic that attempts to retrieve a picture from the rapid_api_zillow client (D:\Repositories\dripr\python\shared_resources\rapid_api_zillow_client_2.py)
- The "Just For Fun... Most Expensive Listing In Your Area" section should still appear in no-address emails using data from the zip code

# Email Requirements
- The email should remain very similar to the existing email
- The email should have an introductory paragraph that is targetting new leads, not targetting past clients. That will require a new prompt similar to this: D:\Repositories\dripr\python\shared_resources\prompts\1st-intro.txt
- The Your Home section should be removed from the email

# Nonfunctional Requirements
- A new campaign won't need a corresponding entry in property_data anymore. Property_data entries should only be created for campaigns with home valuation enabled.
- The campaign table will be reused for both types of campaigns with the following new fields:
  - `home_value_campaign` (Integer, default=1): Boolean flag where 1 = campaigns with home valuation (current behavior), 0 = no-address campaigns
  - `zip_code` (String, nullable): Zip code for no-address campaigns
- For no-address campaigns, active listings and recent sales should be stored with a direct `campaign_id` reference:
  - Add `campaign_id` column to the `active_listings` table
  - Add `campaign_id` column to the `recent_sales` table
  - This allows listings/sales to be associated directly with campaigns without requiring a PropertyData entry
- The RentCast API will only return sold/sale properties in the zip code if thats what we provide. Its possible that there arent enough sold/sales in the zip code so we want to be able to look outside of the zip as well. So we need to continue to provide a lat, lon, and radius as we are doing now. You can lookup the lat and long in the zip code table based off of the zip. If the zip cant be found, throw an error.
