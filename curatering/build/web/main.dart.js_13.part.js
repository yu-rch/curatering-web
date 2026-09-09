((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,B,C,A={
di(d,e,f,g){var x=null
return new B.EQ(!0,f,x,x,x,g,x,x,!1,x,!0,x,new A.aeU(e,d,g,x,x),x)},
aeU:function aeU(d,e,f,g,h){var _=this
_.c=d
_.d=e
_.e=f
_.f=g
_.a=h},
cs9(){return new b.G.XMLHttpRequest()},
csb(){return b.G.document.createElement("img")},
c8V(d,e,f){var x=new A.acK(d,B.a([],y.v),B.a([],y.l),B.a([],y.u))
x.aAE(d,e,f)
return x},
EK:function EK(d,e,f,g){var _=this
_.a=d
_.b=e
_.c=f
_.d=g},
aEd:function aEd(d,e,f){this.a=d
this.b=e
this.c=f},
aEe:function aEe(d,e){this.a=d
this.b=e},
aEb:function aEb(d,e,f){this.a=d
this.b=e
this.c=f},
aEc:function aEc(d,e,f){this.a=d
this.b=e
this.c=f},
acK:function acK(d,e,f,g){var _=this
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
bdB:function bdB(d){this.a=d},
bdC:function bdC(d,e){this.a=d
this.b=e},
bdD:function bdD(d){this.a=d},
bdE:function bdE(d){this.a=d},
bdF:function bdF(d){this.a=d},
GS:function GS(d,e){this.a=d
this.b=e},
cla(d,e){return new A.EL("HTTP request failed, statusCode: "+d+", "+e.j(0))},
aQR:function aQR(d,e){this.a=d
this.b=e},
EL:function EL(d){this.b=d},
clf(d,e){var x=new A.a4A(B.a([],y.v),B.a([],y.l),B.a([],y.u))
x.aAp(d,e)
return x},
a4A:function a4A(d,e,f){var _=this
_.a=d
_.b=e
_.e=_.d=_.c=null
_.f=!1
_.r=0
_.w=!1
_.x=f},
aEA:function aEA(d,e){this.a=d
this.b=e},
nq(d,e,f,g,h,i){var x=null
return new B.zw(B.c_o(x,x,new A.EK(d,1,x,D.bCD)),e,i,h,x,C.d7,f,C.an,g,x)}},D,E
J=c[1]
B=c[0]
C=c[2]
A=a.updateHolder(c[22],A)
D=c[28]
E=c[41]
A.aeU.prototype={
C(d){var x,w=null,v=this.e,u=w
if(v==null)x=u
else{v=v.a
if(v==null)v=u
else{v=v.Z(C.dp)
v=v==null?w:v.r}x=v}if(x==null)x=14
v=B.bO(d,C.bG)
v=v==null?w:v.gc1()
v=B.Y((v==null?C.bn:v).b6(x)/14,1,2)
B.c6A(d)
v=B.aE(8,4,v-1)
v.toString
u=B.a([this.d,new B.dD(1,C.bX,this.c,w)],y.D)
return B.I(u,C.t,C.j,C.a0,v,w)}}
A.EK.prototype={
qo(d){return new B.eX(this,y.i)},
tG(d,e){return A.c8V(this.CU(d,e),d.a,null)},
qn(d,e){return A.c8V(this.CU(d,e),d.a,null)},
CU(d,e){return this.aSO(d,e)},
aSO(d,e){var x=0,w=B.m(y.R),v,u=2,t=[],s=this,r,q,p,o,n
var $async$CU=B.n(function(f,g){if(f===1){t.push(g)
x=u}for(;;)switch(x){case 0:p=new A.aEd(s,e,d)
o=new A.aEe(s,d)
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
return B.d(p.$0(),$async$CU)
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
case 4:case 1:return B.k(v,w)
case 2:return B.j(t.at(-1),w)}})
return B.l($async$CU,w)},
DP(d){var x=0,w=B.m(y.p),v,u=this,t,s,r,q,p,o,n
var $async$DP=B.n(function(e,f){if(e===1)return B.j(f,w)
for(;;)switch(x){case 0:s=u.a
r=B.Bw().Z(s)
q=new B.aJ($.aV,y.Z)
p=new B.br(q,y.x)
o=A.cs9()
o.open("GET",s,!0)
o.responseType="arraybuffer"
o.addEventListener("load",B.ho(new A.aEb(o,p,r)))
o.addEventListener("error",B.ho(new A.aEc(p,o,r)))
o.send()
x=3
return B.d(q,$async$DP)
case 3:s=o.response
s.toString
t=B.a4n(y.a.a(s),0,null)
if(t.byteLength===0)throw B.q(A.cla(B.al(o,"status"),r))
n=d
x=4
return B.d(B.MB(t),$async$DP)
case 4:v=n.$1(f)
x=1
break
case 1:return B.k(v,w)}})
return B.l($async$DP,w)},
m(d,e){var x=this
if(e==null)return!1
if(J.au(e)!==B.a3(x))return!1
return e instanceof A.EK&&e.a===x.a&&e.b===x.b&&e.d===x.d&&B.Jj(e.c,x.c)},
gG(d){var x=this
return B.am(x.a,x.b,x.d,E.TH.hR(x.c),C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c)},
j(d){var x=this
return'NetworkImage("'+x.a+'", scale: '+C.v.L(x.b,1)+", webHtmlElementStrategy: "+x.d.b+", headers: "+B.h(x.c)+")"}}
A.acK.prototype={
aAE(d,e,f){var x=this
x.e=e
x.y.dk(new A.bdB(x),new A.bdC(x,f),y.P)},
gapz(){var x=this,w=x.at
return w===$?x.at=new B.kp(new A.bdD(x),new A.bdE(x),new A.bdF(x)):w},
a2Y(){var x,w=this
if(w.z){x=w.Q
x===$&&B.b()
x.R(w.gapz())}w.as=!0
w.avy()}}
A.GS.prototype={
t7(){return new A.GS(this.a,this.b)},
l(){},
geH(){return B.ap(B.cC("Could not create image data for this image because access to it is restricted by the Same-Origin Policy.\nSee https://developer.mozilla.org/en-US/docs/Web/Security/Same-origin_policy"))},
giH(){return 1},
ga6_(){var x=this.a
return C.p.bh(4*x.naturalWidth*x.naturalHeight)},
$ijZ:1,
gnh(){return this.b}}
A.aQR.prototype={
O(){return"WebHtmlElementStrategy."+this.b}}
A.EL.prototype={
j(d){return this.b},
$icl:1}
A.a4A.prototype={
aAp(d,e){d.dk(this.gau1(),new A.aEA(this,e),y.H)}}
var z=a.updateTypes([])
A.aEd.prototype={
$0(){var x=0,w=B.m(y.R),v,u=this,t,s,r
var $async$$0=B.n(function(d,e){if(d===1)return B.j(e,w)
for(;;)switch(x){case 0:t=u.c
s=B
r=B
x=3
return B.d(u.a.DP(u.b),$async$$0)
case 3:v=s.NY(r.dR(e,y.p),t.a,null,t.b)
x=1
break
case 1:return B.k(v,w)}})
return B.l($async$$0,w)},
$S:332}
A.aEe.prototype={
$0(){var x=0,w=B.m(y.R),v,u=this,t,s,r
var $async$$0=B.n(function(d,e){if(d===1)return B.j(e,w)
for(;;)switch(x){case 0:s=A.csb()
r=u.b.a
s.src=r
x=3
return B.d(B.i0(s.decode(),y.X),$async$$0)
case 3:t=A.clf(B.dR(new A.GS(s,r),y.J),null)
t.e=r
v=t
x=1
break
case 1:return B.k(v,w)}})
return B.l($async$$0,w)},
$S:332}
A.aEb.prototype={
$1(d){var x=this.a,w=x.status,v=w>=200&&w<300,u=w>307&&w<400,t=v||w===0||w===304||u,s=this.b
if(t)s.ds(x)
else s.hN(new A.EL("HTTP request failed, statusCode: "+B.h(w)+", "+this.c.j(0)))},
$S:41}
A.aEc.prototype={
$1(d){return this.a.hN(new A.EL("HTTP request failed, statusCode: "+B.h(this.b.status)+", "+this.c.j(0)))},
$S:8}
A.bdB.prototype={
$1(d){var x=this.a
x.z=!0
if(x.as){d.Ew()
return}x.Q!==$&&B.bV()
x.Q=d
d.a3(x.gapz())},
$S:956}
A.bdC.prototype={
$2(d,e){this.a.xc(B.bS("resolving an image stream completer"),d,this.b,!0,e)},
$S:23}
A.bdD.prototype={
$2(d,e){this.a.U3(d)},
$S:300}
A.bdE.prototype={
$1(d){this.a.bj4(d)},
$S:957}
A.bdF.prototype={
$2(d,e){this.a.bj3(d,e)},
$S:135}
A.aEA.prototype={
$2(d,e){this.a.xc(B.bS("resolving a single-frame image stream"),d,this.b,!0,e)},
$S:23};(function inheritance(){var x=a.inherit,w=a.inheritMany
x(A.aeU,B.ao)
x(A.EK,B.hN)
w(B.kL,[A.aEd,A.aEe])
w(B.i6,[A.aEb,A.aEc,A.bdB,A.bdE])
w(B.js,[A.acK,A.a4A])
w(B.md,[A.bdC,A.bdD,A.bdF,A.aEA])
w(B.Z,[A.GS,A.EL])
x(A.aQR,B.o4)})()
B.n0(b.typeUniverse,JSON.parse('{"aeU":{"ao":[],"f":[]},"EK":{"hN":["c_3"],"hN.T":"c_3"},"acK":{"js":[]},"GS":{"jZ":[]},"c_3":{"hN":["c_3"]},"EL":{"cl":[]},"a4A":{"js":[]}}'))
var y=(function rtii(){var x=B.an
return{p:x("hu"),J:x("jZ"),R:x("js"),v:x("E<kp>"),D:x("E<f>"),u:x("E<~()>"),l:x("E<~(Z,d7?)>"),a:x("qv"),P:x("bY"),i:x("eX<EK>"),x:x("br<bR>"),Z:x("aJ<bR>"),X:x("Z?"),H:x("~")}})();(function constants(){D.f3=new B.bC(45e6)
D.dV=new B.bl(null,2,null,null)
D.bCD=new A.aQR(0,"never")})()};
(a=>{a["GdG4rHnx4l8RqNoLz/BEBMV36II="]=a.current})($__dart_deferred_initializers__);