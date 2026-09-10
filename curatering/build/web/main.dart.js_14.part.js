((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,B,C,A={
di(d,e,f,g){var x=null
return new B.EQ(!0,f,x,x,x,g,x,x,!1,x,!0,x,new A.aeR(e,d,g,x,x),x)},
aeR:function aeR(d,e,f,g,h){var _=this
_.c=d
_.d=e
_.e=f
_.f=g
_.a=h},
crU(){return new b.G.XMLHttpRequest()},
crW(){return b.G.document.createElement("img")},
c8K(d,e,f){var x=new A.acI(d,B.a([],y.v),B.a([],y.l),B.a([],y.u))
x.aAA(d,e,f)
return x},
EK:function EK(d,e,f,g){var _=this
_.a=d
_.b=e
_.c=f
_.d=g},
aE8:function aE8(d,e,f){this.a=d
this.b=e
this.c=f},
aE9:function aE9(d,e){this.a=d
this.b=e},
aE6:function aE6(d,e,f){this.a=d
this.b=e
this.c=f},
aE7:function aE7(d,e,f){this.a=d
this.b=e
this.c=f},
acI:function acI(d,e,f,g){var _=this
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
bdt:function bdt(d){this.a=d},
bdu:function bdu(d,e){this.a=d
this.b=e},
bdv:function bdv(d){this.a=d},
bdw:function bdw(d){this.a=d},
bdx:function bdx(d){this.a=d},
GS:function GS(d,e){this.a=d
this.b=e},
ckV(d,e){return new A.EL("HTTP request failed, statusCode: "+d+", "+e.j(0))},
aQJ:function aQJ(d,e){this.a=d
this.b=e},
EL:function EL(d){this.b=d},
cl_(d,e){var x=new A.a4z(B.a([],y.v),B.a([],y.l),B.a([],y.u))
x.aAl(d,e)
return x},
a4z:function a4z(d,e,f){var _=this
_.a=d
_.b=e
_.e=_.d=_.c=null
_.f=!1
_.r=0
_.w=!1
_.x=f},
aEv:function aEv(d,e){this.a=d
this.b=e},
nq(d,e,f,g,h,i){var x=null
return new B.zv(B.c_e(x,x,new A.EK(d,1,x,D.bCC)),e,i,h,x,C.d7,f,C.an,g,x)}},D,E
J=c[1]
B=c[0]
C=c[2]
A=a.updateHolder(c[22],A)
D=c[28]
E=c[42]
A.aeR.prototype={
C(d){var x,w=null,v=this.e,u=w
if(v==null)x=u
else{v=v.a
if(v==null)v=u
else{v=v.Z(C.dp)
v=v==null?w:v.r}x=v}if(x==null)x=14
v=B.bO(d,C.bG)
v=v==null?w:v.gc1()
v=B.Y((v==null?C.bn:v).b6(x)/14,1,2)
B.c6p(d)
v=B.aE(8,4,v-1)
v.toString
u=B.a([this.d,new B.dC(1,C.bX,this.c,w)],y.D)
return B.H(u,C.t,C.j,C.a0,v,w)}}
A.EK.prototype={
qo(d){return new B.eX(this,y.i)},
tG(d,e){return A.c8K(this.CT(d,e),d.a,null)},
qn(d,e){return A.c8K(this.CT(d,e),d.a,null)},
CT(d,e){return this.aSJ(d,e)},
aSJ(d,e){var x=0,w=B.m(y.R),v,u=2,t=[],s=this,r,q,p,o,n
var $async$CT=B.n(function(f,g){if(f===1){t.push(g)
x=u}for(;;)switch(x){case 0:p=new A.aE8(s,e,d)
o=new A.aE9(s,d)
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
return B.d(p.$0(),$async$CT)
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
return B.l($async$CT,w)},
DO(d){var x=0,w=B.m(y.p),v,u=this,t,s,r,q,p,o,n
var $async$DO=B.n(function(e,f){if(e===1)return B.j(f,w)
for(;;)switch(x){case 0:s=u.a
r=B.Bv().Z(s)
q=new B.aJ($.aU,y.Z)
p=new B.br(q,y.x)
o=A.crU()
o.open("GET",s,!0)
o.responseType="arraybuffer"
o.addEventListener("load",B.ho(new A.aE6(o,p,r)))
o.addEventListener("error",B.ho(new A.aE7(p,o,r)))
o.send()
x=3
return B.d(q,$async$DO)
case 3:s=o.response
s.toString
t=B.a4m(y.a.a(s),0,null)
if(t.byteLength===0)throw B.q(A.ckV(B.al(o,"status"),r))
n=d
x=4
return B.d(B.Mx(t),$async$DO)
case 4:v=n.$1(f)
x=1
break
case 1:return B.k(v,w)}})
return B.l($async$DO,w)},
m(d,e){var x=this
if(e==null)return!1
if(J.au(e)!==B.a3(x))return!1
return e instanceof A.EK&&e.a===x.a&&e.b===x.b&&e.d===x.d&&B.Ji(e.c,x.c)},
gG(d){var x=this
return B.am(x.a,x.b,x.d,E.TH.hR(x.c),C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c)},
j(d){var x=this
return'NetworkImage("'+x.a+'", scale: '+C.v.L(x.b,1)+", webHtmlElementStrategy: "+x.d.b+", headers: "+B.h(x.c)+")"}}
A.acI.prototype={
aAA(d,e,f){var x=this
x.e=e
x.y.dk(new A.bdt(x),new A.bdu(x,f),y.P)},
gapw(){var x=this,w=x.at
return w===$?x.at=new B.kp(new A.bdv(x),new A.bdw(x),new A.bdx(x)):w},
a2V(){var x,w=this
if(w.z){x=w.Q
x===$&&B.b()
x.R(w.gapw())}w.as=!0
w.avv()}}
A.GS.prototype={
t7(){return new A.GS(this.a,this.b)},
l(){},
geH(){return B.ap(B.cC("Could not create image data for this image because access to it is restricted by the Same-Origin Policy.\nSee https://developer.mozilla.org/en-US/docs/Web/Security/Same-origin_policy"))},
giH(){return 1},
ga5X(){var x=this.a
return C.p.bh(4*x.naturalWidth*x.naturalHeight)},
$ijZ:1,
gnf(){return this.b}}
A.aQJ.prototype={
O(){return"WebHtmlElementStrategy."+this.b}}
A.EL.prototype={
j(d){return this.b},
$icl:1}
A.a4z.prototype={
aAl(d,e){d.dk(this.gatZ(),new A.aEv(this,e),y.H)}}
var z=a.updateTypes([])
A.aE8.prototype={
$0(){var x=0,w=B.m(y.R),v,u=this,t,s,r
var $async$$0=B.n(function(d,e){if(d===1)return B.j(e,w)
for(;;)switch(x){case 0:t=u.c
s=B
r=B
x=3
return B.d(u.a.DO(u.b),$async$$0)
case 3:v=s.NU(r.dR(e,y.p),t.a,null,t.b)
x=1
break
case 1:return B.k(v,w)}})
return B.l($async$$0,w)},
$S:332}
A.aE9.prototype={
$0(){var x=0,w=B.m(y.R),v,u=this,t,s,r
var $async$$0=B.n(function(d,e){if(d===1)return B.j(e,w)
for(;;)switch(x){case 0:s=A.crW()
r=u.b.a
s.src=r
x=3
return B.d(B.i0(s.decode(),y.X),$async$$0)
case 3:t=A.cl_(B.dR(new A.GS(s,r),y.J),null)
t.e=r
v=t
x=1
break
case 1:return B.k(v,w)}})
return B.l($async$$0,w)},
$S:332}
A.aE6.prototype={
$1(d){var x=this.a,w=x.status,v=w>=200&&w<300,u=w>307&&w<400,t=v||w===0||w===304||u,s=this.b
if(t)s.ds(x)
else s.hN(new A.EL("HTTP request failed, statusCode: "+B.h(w)+", "+this.c.j(0)))},
$S:41}
A.aE7.prototype={
$1(d){return this.a.hN(new A.EL("HTTP request failed, statusCode: "+B.h(this.b.status)+", "+this.c.j(0)))},
$S:8}
A.bdt.prototype={
$1(d){var x=this.a
x.z=!0
if(x.as){d.Ew()
return}x.Q!==$&&B.bV()
x.Q=d
d.a3(x.gapw())},
$S:956}
A.bdu.prototype={
$2(d,e){this.a.xc(B.bS("resolving an image stream completer"),d,this.b,!0,e)},
$S:23}
A.bdv.prototype={
$2(d,e){this.a.U1(d)},
$S:299}
A.bdw.prototype={
$1(d){this.a.biX(d)},
$S:957}
A.bdx.prototype={
$2(d,e){this.a.biW(d,e)},
$S:135}
A.aEv.prototype={
$2(d,e){this.a.xc(B.bS("resolving a single-frame image stream"),d,this.b,!0,e)},
$S:23};(function inheritance(){var x=a.inherit,w=a.inheritMany
x(A.aeR,B.ao)
x(A.EK,B.hN)
w(B.kL,[A.aE8,A.aE9])
w(B.i6,[A.aE6,A.aE7,A.bdt,A.bdw])
w(B.js,[A.acI,A.a4z])
w(B.md,[A.bdu,A.bdv,A.bdx,A.aEv])
w(B.Z,[A.GS,A.EL])
x(A.aQJ,B.o4)})()
B.n0(b.typeUniverse,JSON.parse('{"aeR":{"ao":[],"f":[]},"EK":{"hN":["bZU"],"hN.T":"bZU"},"acI":{"js":[]},"GS":{"jZ":[]},"bZU":{"hN":["bZU"]},"EL":{"cl":[]},"a4z":{"js":[]}}'))
var y=(function rtii(){var x=B.an
return{p:x("hu"),J:x("jZ"),R:x("js"),v:x("E<kp>"),D:x("E<f>"),u:x("E<~()>"),l:x("E<~(Z,d7?)>"),a:x("qv"),P:x("bY"),i:x("eX<EK>"),x:x("br<bR>"),Z:x("aJ<bR>"),X:x("Z?"),H:x("~")}})();(function constants(){D.f3=new B.bC(45e6)
D.dV=new B.bl(null,2,null,null)
D.bCC=new A.aQJ(0,"never")})()};
(a=>{a["kkx194A4aSJ+f/bu1+umtuDA7Y0="]=a.current})($__dart_deferred_initializers__);