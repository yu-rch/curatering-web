((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,B,C,G,A={
dw(d,e,f,g){var x=null
return new F.Hh(!0,f,x,x,x,g,x,x,!1,x,!0,x,new A.aiN(e,d,g,x,x),x)},
aiN:function aiN(d,e,f,g,h){var _=this
_.c=d
_.d=e
_.e=f
_.f=g
_.a=h},
cAJ(){return new b.G.XMLHttpRequest()},
cAL(){return b.G.document.createElement("img")},
cfS(d,e,f){var x=new A.agE(d,B.a([],y.v),B.a([],y.l),B.a([],y.u))
x.aF6(d,e,f)
return x},
Hb:function Hb(d,e,f,g){var _=this
_.a=d
_.b=e
_.c=f
_.d=g},
aIQ:function aIQ(d,e,f){this.a=d
this.b=e
this.c=f},
aIR:function aIR(d,e){this.a=d
this.b=e},
aIO:function aIO(d,e,f){this.a=d
this.b=e
this.c=f},
aIP:function aIP(d,e,f){this.a=d
this.b=e
this.c=f},
agE:function agE(d,e,f,g){var _=this
_.y=d
_.z=!1
_.Q=$
_.as=!1
_.at=$
_.a=e
_.b=f
_.e=_.d=_.c=null
_.f=!1
_.r=0
_.w=!1
_.x=g},
bjj:function bjj(d){this.a=d},
bjk:function bjk(d,e){this.a=d
this.b=e},
bjl:function bjl(d){this.a=d},
bjm:function bjm(d){this.a=d},
bjn:function bjn(d){this.a=d},
Jo:function Jo(d,e){this.a=d
this.b=e},
csQ(d,e){return new A.Hc("HTTP request failed, statusCode: "+d+", "+e.j(0))},
aW1:function aW1(d,e){this.a=d
this.b=e},
Hc:function Hc(d){this.b=d},
csV(d,e){var x=new A.a7Z(B.a([],y.v),B.a([],y.l),B.a([],y.u))
x.aEM(d,e)
return x},
a7Z:function a7Z(d,e,f){var _=this
_.a=d
_.b=e
_.e=_.d=_.c=null
_.f=!1
_.r=0
_.w=!1
_.x=f},
aJc:function aJc(d,e){this.a=d
this.b=e},
pU(d,e,f,g,h,i){var x=null
return new E.B8(H.c5A(x,x,new A.Hb(d,1,x,D.bNM)),e,i,h,x,C.de,f,C.ao,g,x)}},D,H,I,E,F
J=c[1]
B=c[0]
C=c[2]
G=c[51]
A=a.updateHolder(c[31],A)
D=c[76]
H=c[47]
I=c[106]
E=c[49]
F=c[36]
A.aiN.prototype={
D(d){var x,w=null,v=this.e,u=w
if(v==null)x=u
else{v=v.a
if(v==null)v=u
else{v=v.a2(C.dw)
v=v==null?w:v.r}x=v}if(x==null)x=14
v=B.bU(d,C.bI)
v=v==null?w:v.gcf()
v=B.a3((v==null?C.bo:v).bi(x)/14,1,2)
F.cdi(d)
v=B.aG(8,4,v-1)
v.toString
u=B.a([this.d,new B.dY(1,C.c1,this.c,w)],y.D)
return G.L(u,C.u,C.l,C.a0,v,w)}}
A.Hb.prototype={
rY(d){return new B.fj(this,y.i)},
vd(d,e){return A.cfS(this.EN(d,e),d.a,null)},
rX(d,e){return A.cfS(this.EN(d,e),d.a,null)},
EN(d,e){return this.aYc(d,e)},
aYc(d,e){var x=0,w=B.l(y.R),v,u=2,t=[],s=this,r,q,p,o,n
var $async$EN=B.m(function(f,g){if(f===1){t.push(g)
x=u}for(;;)switch(x){case 0:p=new A.aIQ(s,e,d)
o=new A.aIR(s,d)
case 3:switch(s.d.a){case 0:x=5
break
case 2:x=6
break
case 1:x=7
break
default:x=4
break}break
case 5:v=p.$0()
x=1
break
case 6:v=o.$0()
x=1
break
case 7:u=9
x=12
return B.d(p.$0(),$async$EN)
case 12:r=g
v=r
x=1
break
u=2
x=11
break
case 9:u=8
n=t.pop()
r=o.$0()
v=r
x=1
break
x=11
break
case 8:x=2
break
case 11:x=4
break
case 4:case 1:return B.j(v,w)
case 2:return B.i(t.at(-1),w)}})
return B.k($async$EN,w)},
FK(d){var x=0,w=B.l(y.p),v,u=this,t,s,r,q,p,o,n
var $async$FK=B.m(function(e,f){if(e===1)return B.i(f,w)
for(;;)switch(x){case 0:s=u.a
r=B.yN().a2(s)
q=new B.aI($.aW,y.Z)
p=new B.bp(q,y.x)
o=A.cAJ()
o.open("GET",s,!0)
o.responseType="arraybuffer"
o.addEventListener("load",B.hR(new A.aIO(o,p,r)))
o.addEventListener("error",B.hR(new A.aIP(p,o,r)))
o.send()
x=3
return B.d(q,$async$FK)
case 3:s=o.response
s.toString
t=B.a7M(y.a.a(s),0,null)
if(t.byteLength===0)throw B.p(A.csQ(B.ao(o,"status"),r))
n=d
x=4
return B.d(B.Pi(t),$async$FK)
case 4:v=n.$1(f)
x=1
break
case 1:return B.j(v,w)}})
return B.k($async$FK,w)},
l(d,e){var x=this
if(e==null)return!1
if(J.ay(e)!==B.a8(x))return!1
return e instanceof A.Hb&&e.a===x.a&&e.b===x.b&&e.d===x.d&&B.LU(e.c,x.c)},
gC(d){var x=this
return B.ap(x.a,x.b,x.d,I.VS.iM(x.c),C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c)},
j(d){var x=this
return'NetworkImage("'+x.a+'", scale: '+C.k.M(x.b,1)+", webHtmlElementStrategy: "+x.d.b+", headers: "+B.h(x.c)+")"}}
A.agE.prototype={
aF6(d,e,f){var x=this
x.e=e
x.y.dL(new A.bjj(x),new A.bjk(x,f),y.P)},
gatu(){var x=this,w=x.at
return w===$?x.at=new B.l6(new A.bjl(x),new A.bjm(x),new A.bjn(x)):w},
a5T(){var x,w=this
if(w.z){x=w.Q
x===$&&B.b()
x.T(w.gatu())}w.as=!0
w.azG()}}
A.Jo.prototype={
cg(){return new A.Jo(this.a,this.b)},
n(){},
gdr(){return B.aq(B.cN("Could not create image data for this image because access to it is restricted by the Same-Origin Policy.\nSee https://developer.mozilla.org/en-US/docs/Web/Security/Same-origin_policy"))},
gjA(){return 1},
ga8Y(){var x=this.a
return C.i.H(4*x.naturalWidth*x.naturalHeight)},
$ijG:1,
goG(){return this.b}}
A.aW1.prototype={
O(){return"WebHtmlElementStrategy."+this.b}}
A.Hc.prototype={
j(d){return this.b},
$icr:1}
A.a7Z.prototype={
aEM(d,e){d.dL(this.gay7(),new A.aJc(this,e),y.H)}}
var z=a.updateTypes([])
A.aIQ.prototype={
$0(){var x=0,w=B.l(y.R),v,u=this,t,s,r
var $async$$0=B.m(function(d,e){if(d===1)return B.i(e,w)
for(;;)switch(x){case 0:t=u.c
s=E
r=B
x=3
return B.d(u.a.FK(u.b),$async$$0)
case 3:v=s.QF(r.e9(e,y.p),t.a,null,t.b)
x=1
break
case 1:return B.j(v,w)}})
return B.k($async$$0,w)},
$S:222}
A.aIR.prototype={
$0(){var x=0,w=B.l(y.R),v,u=this,t,s,r
var $async$$0=B.m(function(d,e){if(d===1)return B.i(e,w)
for(;;)switch(x){case 0:s=A.cAL()
r=u.b.a
s.src=r
x=3
return B.d(B.iH(s.decode(),y.X),$async$$0)
case 3:t=A.csV(B.e9(new A.Jo(s,r),y.J),null)
t.e=r
v=t
x=1
break
case 1:return B.j(v,w)}})
return B.k($async$$0,w)},
$S:222}
A.aIO.prototype={
$1(d){var x=this.a,w=x.status,v=w>=200&&w<300,u=w>307&&w<400,t=v||w===0||w===304||u,s=this.b
if(t)s.dJ(x)
else s.iF(new A.Hc("HTTP request failed, statusCode: "+B.h(w)+", "+this.c.j(0)))},
$S:34}
A.aIP.prototype={
$1(d){return this.a.iF(new A.Hc("HTTP request failed, statusCode: "+B.h(this.b.status)+", "+this.c.j(0)))},
$S:7}
A.bjj.prototype={
$1(d){var x=this.a
x.z=!0
if(x.as){d.Gw()
return}x.Q!==$&&B.c_()
x.Q=d
d.a6(x.gatu())},
$S:782}
A.bjk.prototype={
$2(d,e){this.a.z0(B.bY("resolving an image stream completer"),d,this.b,!0,e)},
$S:21}
A.bjl.prototype={
$2(d,e){this.a.WE(d)},
$S:783}
A.bjm.prototype={
$1(d){this.a.bpK(d)},
$S:784}
A.bjn.prototype={
$2(d,e){this.a.bpJ(d,e)},
$S:130}
A.aJc.prototype={
$2(d,e){this.a.z0(B.bY("resolving a single-frame image stream"),d,this.b,!0,e)},
$S:21};(function inheritance(){var x=a.inherit,w=a.inheritMany
x(A.aiN,B.am)
x(A.Hb,E.hW)
w(B.eR,[A.aIQ,A.aIR])
w(B.dT,[A.aIO,A.aIP,A.bjj,A.bjm])
w(E.k9,[A.agE,A.a7Z])
w(B.fw,[A.bjk,A.bjl,A.bjn,A.aJc])
w(B.W,[A.Jo,A.Hc])
x(A.aW1,B.i5)})()
B.ey(b.typeUniverse,JSON.parse('{"aiN":{"am":[],"f":[]},"Hb":{"hW":["c4Z"],"hW.T":"c4Z"},"agE":{"k9":[]},"Jo":{"jG":[]},"c4Z":{"hW":["c4Z"]},"Hc":{"cr":[]},"a7Z":{"k9":[]}}'))
var y=(function rtii(){var x=B.a4
return{p:x("hF"),J:x("jG"),R:x("k9"),v:x("A<l6>"),D:x("A<f>"),u:x("A<~()>"),l:x("A<~(W,dq?)>"),a:x("rQ"),P:x("bR"),i:x("fj<Hb>"),x:x("bp<bZ>"),Z:x("aI<bZ>"),X:x("W?"),H:x("~")}})();(function constants(){D.fh=new B.bx(45e6)
D.e3=new B.bn(null,2,null,null)
D.bNM=new A.aW1(0,"never")})()};
(a=>{a["fc01jqHxtT35pX0ZnkW6mcgF3+A="]=a.current})($__dart_deferred_initializers__);