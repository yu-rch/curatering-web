((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,B,C,A={
cAT(){return new b.G.XMLHttpRequest()},
cAV(){return b.G.document.createElement("img")},
cfX(d,e,f){var x=new A.agI(d,B.a([],y.v),B.a([],y.l),B.a([],y.u))
x.aFc(d,e,f)
return x},
Hb:function Hb(d,e,f,g){var _=this
_.a=d
_.b=e
_.c=f
_.d=g},
aIV:function aIV(d,e,f){this.a=d
this.b=e
this.c=f},
aIW:function aIW(d,e){this.a=d
this.b=e},
aIT:function aIT(d,e,f){this.a=d
this.b=e
this.c=f},
aIU:function aIU(d,e,f){this.a=d
this.b=e
this.c=f},
agI:function agI(d,e,f,g){var _=this
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
bjm:function bjm(d){this.a=d},
bjn:function bjn(d,e){this.a=d
this.b=e},
bjo:function bjo(d){this.a=d},
bjp:function bjp(d){this.a=d},
bjq:function bjq(d){this.a=d},
Jp:function Jp(d,e){this.a=d
this.b=e},
csZ(d,e){return new A.Hc("HTTP request failed, statusCode: "+d+", "+e.j(0))},
aW4:function aW4(d,e){this.a=d
this.b=e},
Hc:function Hc(d){this.b=d},
ct3(d,e){var x=new A.a82(B.a([],y.v),B.a([],y.l),B.a([],y.u))
x.aES(d,e)
return x},
a82:function a82(d,e,f){var _=this
_.a=d
_.b=e
_.e=_.d=_.c=null
_.f=!1
_.r=0
_.w=!1
_.x=f},
aJh:function aJh(d,e){this.a=d
this.b=e},
pW(d,e,f,g,h,i){var x=null
return new D.Ba(F.c5G(x,x,new A.Hb(d,1,x,E.bMy)),e,i,h,x,C.dj,f,C.ap,g,x)}},E,F,G,D
J=c[1]
B=c[0]
C=c[2]
A=a.updateHolder(c[33],A)
E=c[110]
F=c[64]
G=c[156]
D=c[66]
A.Hb.prototype={
rY(d){return new B.fn(this,y.i)},
vd(d,e){return A.cfX(this.EO(d,e),d.a,null)},
rX(d,e){return A.cfX(this.EO(d,e),d.a,null)},
EO(d,e){return this.aYi(d,e)},
aYi(d,e){var x=0,w=B.l(y.R),v,u=2,t=[],s=this,r,q,p,o,n
var $async$EO=B.m(function(f,g){if(f===1){t.push(g)
x=u}for(;;)switch(x){case 0:p=new A.aIV(s,e,d)
o=new A.aIW(s,d)
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
return B.d(p.$0(),$async$EO)
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
return B.k($async$EO,w)},
FL(d){var x=0,w=B.l(y.p),v,u=this,t,s,r,q,p,o,n
var $async$FL=B.m(function(e,f){if(e===1)return B.i(f,w)
for(;;)switch(x){case 0:s=u.a
r=B.yQ().a2(s)
q=new B.aI($.aX,y.Z)
p=new B.bq(q,y.x)
o=A.cAT()
o.open("GET",s,!0)
o.responseType="arraybuffer"
o.addEventListener("load",B.hU(new A.aIT(o,p,r)))
o.addEventListener("error",B.hU(new A.aIU(p,o,r)))
o.send()
x=3
return B.d(q,$async$FL)
case 3:s=o.response
s.toString
t=B.a7Q(y.a.a(s),0,null)
if(t.byteLength===0)throw B.p(A.csZ(B.ao(o,"status"),r))
n=d
x=4
return B.d(B.Pl(t),$async$FL)
case 4:v=n.$1(f)
x=1
break
case 1:return B.j(v,w)}})
return B.k($async$FL,w)},
l(d,e){var x=this
if(e==null)return!1
if(J.ay(e)!==B.a8(x))return!1
return e instanceof A.Hb&&e.a===x.a&&e.b===x.b&&e.d===x.d&&B.LV(e.c,x.c)},
gC(d){var x=this
return B.ap(x.a,x.b,x.d,G.VL.iM(x.c),C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c)},
j(d){var x=this
return'NetworkImage("'+x.a+'", scale: '+C.k.M(x.b,1)+", webHtmlElementStrategy: "+x.d.b+", headers: "+B.h(x.c)+")"}}
A.agI.prototype={
aFc(d,e,f){var x=this
x.e=e
x.y.dL(new A.bjm(x),new A.bjn(x,f),y.P)},
gaty(){var x=this,w=x.at
return w===$?x.at=new B.l9(new A.bjo(x),new A.bjp(x),new A.bjq(x)):w},
a5W(){var x,w=this
if(w.z){x=w.Q
x===$&&B.b()
x.T(w.gaty())}w.as=!0
w.azM()}}
A.Jp.prototype={
cg(){return new A.Jp(this.a,this.b)},
n(){},
gdr(){return B.aq(B.cP("Could not create image data for this image because access to it is restricted by the Same-Origin Policy.\nSee https://developer.mozilla.org/en-US/docs/Web/Security/Same-origin_policy"))},
gjA(){return 1},
ga9_(){var x=this.a
return C.i.H(4*x.naturalWidth*x.naturalHeight)},
$ijI:1,
goH(){return this.b}}
A.aW4.prototype={
O(){return"WebHtmlElementStrategy."+this.b}}
A.Hc.prototype={
j(d){return this.b},
$ics:1}
A.a82.prototype={
aES(d,e){d.dL(this.gayd(),new A.aJh(this,e),y.H)}}
var z=a.updateTypes([])
A.aIV.prototype={
$0(){var x=0,w=B.l(y.R),v,u=this,t,s,r
var $async$$0=B.m(function(d,e){if(d===1)return B.i(e,w)
for(;;)switch(x){case 0:t=u.c
s=D
r=B
x=3
return B.d(u.a.FL(u.b),$async$$0)
case 3:v=s.QI(r.eb(e,y.p),t.a,null,t.b)
x=1
break
case 1:return B.j(v,w)}})
return B.k($async$$0,w)},
$S:321}
A.aIW.prototype={
$0(){var x=0,w=B.l(y.R),v,u=this,t,s,r
var $async$$0=B.m(function(d,e){if(d===1)return B.i(e,w)
for(;;)switch(x){case 0:s=A.cAV()
r=u.b.a
s.src=r
x=3
return B.d(B.iJ(s.decode(),y.X),$async$$0)
case 3:t=A.ct3(B.eb(new A.Jp(s,r),y.J),null)
t.e=r
v=t
x=1
break
case 1:return B.j(v,w)}})
return B.k($async$$0,w)},
$S:321}
A.aIT.prototype={
$1(d){var x=this.a,w=x.status,v=w>=200&&w<300,u=w>307&&w<400,t=v||w===0||w===304||u,s=this.b
if(t)s.dJ(x)
else s.iF(new A.Hc("HTTP request failed, statusCode: "+B.h(w)+", "+this.c.j(0)))},
$S:35}
A.aIU.prototype={
$1(d){return this.a.iF(new A.Hc("HTTP request failed, statusCode: "+B.h(this.b.status)+", "+this.c.j(0)))},
$S:7}
A.bjm.prototype={
$1(d){var x=this.a
x.z=!0
if(x.as){d.Gx()
return}x.Q!==$&&B.c_()
x.Q=d
d.a6(x.gaty())},
$S:782}
A.bjn.prototype={
$2(d,e){this.a.z0(B.bY("resolving an image stream completer"),d,this.b,!0,e)},
$S:21}
A.bjo.prototype={
$2(d,e){this.a.WG(d)},
$S:783}
A.bjp.prototype={
$1(d){this.a.bpS(d)},
$S:784}
A.bjq.prototype={
$2(d,e){this.a.bpR(d,e)},
$S:124}
A.aJh.prototype={
$2(d,e){this.a.z0(B.bY("resolving a single-frame image stream"),d,this.b,!0,e)},
$S:21};(function inheritance(){var x=a.inherit,w=a.inheritMany
x(A.Hb,D.hY)
w(B.ed,[A.aIV,A.aIW])
w(B.de,[A.aIT,A.aIU,A.bjm,A.bjp])
w(D.ka,[A.agI,A.a82])
w(B.ex,[A.bjn,A.bjo,A.bjq,A.aJh])
w(B.W,[A.Jp,A.Hc])
x(A.aW4,B.fZ)})()
B.dF(b.typeUniverse,JSON.parse('{"Hb":{"hY":["c54"],"hY.T":"c54"},"agI":{"ka":[]},"Jp":{"jI":[]},"c54":{"hY":["c54"]},"Hc":{"cs":[]},"a82":{"ka":[]}}'))
var y=(function rtii(){var x=B.Y
return{p:x("hI"),J:x("jI"),R:x("ka"),v:x("z<l9>"),u:x("z<~()>"),l:x("z<~(W,dt?)>"),a:x("rU"),P:x("bR"),i:x("fn<Hb>"),x:x("bq<bZ>"),Z:x("aI<bZ>"),X:x("W?"),H:x("~")}})();(function constants(){E.fm=new B.by(45e6)
E.bMy=new A.aW4(0,"never")})()};
(a=>{a["y00Ti+PALUKDbnLUxCwt04OOtRM="]=a.current})($__dart_deferred_initializers__);