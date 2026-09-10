((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,B,C,G,F,A={
du(d,e,f,g){var x=null
return new F.He(!0,f,x,x,x,g,x,x,!1,x,!0,x,new A.aiN(e,d,g,x,x),x)},
aiN:function aiN(d,e,f,g,h){var _=this
_.c=d
_.d=e
_.e=f
_.f=g
_.a=h},
cAt(){return new b.G.XMLHttpRequest()},
cAv(){return b.G.document.createElement("img")},
cfG(d,e,f){var x=new A.agE(d,B.a([],y.v),B.a([],y.l),B.a([],y.u))
x.aF0(d,e,f)
return x},
H8:function H8(d,e,f,g){var _=this
_.a=d
_.b=e
_.c=f
_.d=g},
aIO:function aIO(d,e,f){this.a=d
this.b=e
this.c=f},
aIP:function aIP(d,e){this.a=d
this.b=e},
aIM:function aIM(d,e,f){this.a=d
this.b=e
this.c=f},
aIN:function aIN(d,e,f){this.a=d
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
bjb:function bjb(d){this.a=d},
bjc:function bjc(d,e){this.a=d
this.b=e},
bjd:function bjd(d){this.a=d},
bje:function bje(d){this.a=d},
bjf:function bjf(d){this.a=d},
Jm:function Jm(d,e){this.a=d
this.b=e},
csA(d,e){return new A.H9("HTTP request failed, statusCode: "+d+", "+e.j(0))},
aW_:function aW_(d,e){this.a=d
this.b=e},
H9:function H9(d){this.b=d},
csF(d,e){var x=new A.a7Z(B.a([],y.v),B.a([],y.l),B.a([],y.u))
x.aEG(d,e)
return x},
a7Z:function a7Z(d,e,f){var _=this
_.a=d
_.b=e
_.e=_.d=_.c=null
_.f=!1
_.r=0
_.w=!1
_.x=f},
aJa:function aJa(d,e){this.a=d
this.b=e},
pN(d,e,f,g,h,i){var x=null
return new E.B5(F.c5o(x,x,new A.H8(d,1,x,D.bNG)),e,i,h,x,C.de,f,C.ao,g,x)}},D,E,H
J=c[1]
B=c[0]
C=c[2]
G=c[36]
F=c[30]
A=a.updateHolder(c[26],A)
D=c[55]
E=c[34]
H=c[71]
A.aiN.prototype={
D(d){var x,w=null,v=this.e,u=w
if(v==null)x=u
else{v=v.a
if(v==null)v=u
else{v=v.a2(C.dw)
v=v==null?w:v.r}x=v}if(x==null)x=14
v=B.bT(d,C.bI)
v=v==null?w:v.gcf()
v=B.a1((v==null?C.bo:v).bi(x)/14,1,2)
F.cd6(d)
v=B.aG(8,4,v-1)
v.toString
u=B.a([this.d,new B.dS(1,C.bZ,this.c,w)],y.D)
return G.L(u,C.u,C.l,C.a0,v,w)}}
A.H8.prototype={
rX(d){return new B.fh(this,y.i)},
vb(d,e){return A.cfG(this.EJ(d,e),d.a,null)},
rW(d,e){return A.cfG(this.EJ(d,e),d.a,null)},
EJ(d,e){return this.aY1(d,e)},
aY1(d,e){var x=0,w=B.l(y.R),v,u=2,t=[],s=this,r,q,p,o,n
var $async$EJ=B.m(function(f,g){if(f===1){t.push(g)
x=u}for(;;)switch(x){case 0:p=new A.aIO(s,e,d)
o=new A.aIP(s,d)
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
return B.d(p.$0(),$async$EJ)
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
return B.k($async$EJ,w)},
FG(d){var x=0,w=B.l(y.p),v,u=this,t,s,r,q,p,o,n
var $async$FG=B.m(function(e,f){if(e===1)return B.i(f,w)
for(;;)switch(x){case 0:s=u.a
r=B.Dm().a2(s)
q=new B.aI($.aW,y.Z)
p=new B.bp(q,y.x)
o=A.cAt()
o.open("GET",s,!0)
o.responseType="arraybuffer"
o.addEventListener("load",B.hP(new A.aIM(o,p,r)))
o.addEventListener("error",B.hP(new A.aIN(p,o,r)))
o.send()
x=3
return B.d(q,$async$FG)
case 3:s=o.response
s.toString
t=B.a7M(y.a.a(s),0,null)
if(t.byteLength===0)throw B.p(A.csA(B.ao(o,"status"),r))
n=d
x=4
return B.d(B.Pf(t),$async$FG)
case 4:v=n.$1(f)
x=1
break
case 1:return B.j(v,w)}})
return B.k($async$FG,w)},
l(d,e){var x=this
if(e==null)return!1
if(J.ax(e)!==B.a7(x))return!1
return e instanceof A.H8&&e.a===x.a&&e.b===x.b&&e.d===x.d&&B.LS(e.c,x.c)},
gC(d){var x=this
return B.ap(x.a,x.b,x.d,H.VP.iN(x.c),C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c)},
j(d){var x=this
return'NetworkImage("'+x.a+'", scale: '+C.k.M(x.b,1)+", webHtmlElementStrategy: "+x.d.b+", headers: "+B.h(x.c)+")"}}
A.agE.prototype={
aF0(d,e,f){var x=this
x.e=e
x.y.dK(new A.bjb(x),new A.bjc(x,f),y.P)},
gato(){var x=this,w=x.at
return w===$?x.at=new B.l2(new A.bjd(x),new A.bje(x),new A.bjf(x)):w},
a5N(){var x,w=this
if(w.z){x=w.Q
x===$&&B.b()
x.T(w.gato())}w.as=!0
w.azA()}}
A.Jm.prototype={
cg(){return new A.Jm(this.a,this.b)},
n(){},
gdr(){return B.aq(B.cN("Could not create image data for this image because access to it is restricted by the Same-Origin Policy.\nSee https://developer.mozilla.org/en-US/docs/Web/Security/Same-origin_policy"))},
gjA(){return 1},
ga8S(){var x=this.a
return C.i.H(4*x.naturalWidth*x.naturalHeight)},
$ijC:1,
goE(){return this.b}}
A.aW_.prototype={
O(){return"WebHtmlElementStrategy."+this.b}}
A.H9.prototype={
j(d){return this.b},
$ico:1}
A.a7Z.prototype={
aEG(d,e){d.dK(this.gay1(),new A.aJa(this,e),y.H)}}
var z=a.updateTypes([])
A.aIO.prototype={
$0(){var x=0,w=B.l(y.R),v,u=this,t,s,r
var $async$$0=B.m(function(d,e){if(d===1)return B.i(e,w)
for(;;)switch(x){case 0:t=u.c
s=E
r=B
x=3
return B.d(u.a.FG(u.b),$async$$0)
case 3:v=s.QD(r.e7(e,y.p),t.a,null,t.b)
x=1
break
case 1:return B.j(v,w)}})
return B.k($async$$0,w)},
$S:305}
A.aIP.prototype={
$0(){var x=0,w=B.l(y.R),v,u=this,t,s,r
var $async$$0=B.m(function(d,e){if(d===1)return B.i(e,w)
for(;;)switch(x){case 0:s=A.cAv()
r=u.b.a
s.src=r
x=3
return B.d(B.iG(s.decode(),y.X),$async$$0)
case 3:t=A.csF(B.e7(new A.Jm(s,r),y.J),null)
t.e=r
v=t
x=1
break
case 1:return B.j(v,w)}})
return B.k($async$$0,w)},
$S:305}
A.aIM.prototype={
$1(d){var x=this.a,w=x.status,v=w>=200&&w<300,u=w>307&&w<400,t=v||w===0||w===304||u,s=this.b
if(t)s.dI(x)
else s.iI(new A.H9("HTTP request failed, statusCode: "+B.h(w)+", "+this.c.j(0)))},
$S:36}
A.aIN.prototype={
$1(d){return this.a.iI(new A.H9("HTTP request failed, statusCode: "+B.h(this.b.status)+", "+this.c.j(0)))},
$S:7}
A.bjb.prototype={
$1(d){var x=this.a
x.z=!0
if(x.as){d.Gs()
return}x.Q!==$&&B.c_()
x.Q=d
d.a7(x.gato())},
$S:780}
A.bjc.prototype={
$2(d,e){this.a.yX(B.bY("resolving an image stream completer"),d,this.b,!0,e)},
$S:21}
A.bjd.prototype={
$2(d,e){this.a.WA(d)},
$S:781}
A.bje.prototype={
$1(d){this.a.bpu(d)},
$S:782}
A.bjf.prototype={
$2(d,e){this.a.bpt(d,e)},
$S:122}
A.aJa.prototype={
$2(d,e){this.a.yX(B.bY("resolving a single-frame image stream"),d,this.b,!0,e)},
$S:21};(function inheritance(){var x=a.inherit,w=a.inheritMany
x(A.aiN,B.an)
x(A.H8,E.hU)
w(B.hA,[A.aIO,A.aIP])
w(B.eG,[A.aIM,A.aIN,A.bjb,A.bje])
w(E.k7,[A.agE,A.a7Z])
w(B.i9,[A.bjc,A.bjd,A.bjf,A.aJa])
w(B.X,[A.Jm,A.H9])
x(A.aW_,B.j5)})()
B.hO(b.typeUniverse,JSON.parse('{"aiN":{"an":[],"f":[]},"H8":{"hU":["c4N"],"hU.T":"c4N"},"agE":{"k7":[]},"Jm":{"jC":[]},"c4N":{"hU":["c4N"]},"H9":{"co":[]},"a7Z":{"k7":[]}}'))
var y=(function rtii(){var x=B.ac
return{p:x("hB"),J:x("jC"),R:x("k7"),v:x("B<l2>"),D:x("B<f>"),u:x("B<~()>"),l:x("B<~(X,dq?)>"),a:x("rJ"),P:x("bU"),i:x("fh<H8>"),x:x("bp<bZ>"),Z:x("aI<bZ>"),X:x("X?"),H:x("~")}})();(function constants(){D.fh=new B.bx(45e6)
D.e3=new B.bn(null,2,null,null)
D.bNG=new A.aW_(0,"never")})()};
(a=>{a["X36H6j0YkIula5/KAEapLkvW/TI="]=a.current})($__dart_deferred_initializers__);