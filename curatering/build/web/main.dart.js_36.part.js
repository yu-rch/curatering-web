((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,B,C,A={
cAZ(){return new b.G.XMLHttpRequest()},
cB0(){return b.G.document.createElement("img")},
cg1(d,e,f){var x=new A.agL(d,B.a([],y.v),B.a([],y.l),B.a([],y.u))
x.aFc(d,e,f)
return x},
He:function He(d,e,f,g){var _=this
_.a=d
_.b=e
_.c=f
_.d=g},
aJ0:function aJ0(d,e,f){this.a=d
this.b=e
this.c=f},
aJ1:function aJ1(d,e){this.a=d
this.b=e},
aIZ:function aIZ(d,e,f){this.a=d
this.b=e
this.c=f},
aJ_:function aJ_(d,e,f){this.a=d
this.b=e
this.c=f},
agL:function agL(d,e,f,g){var _=this
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
bjt:function bjt(d){this.a=d},
bju:function bju(d,e){this.a=d
this.b=e},
bjv:function bjv(d){this.a=d},
bjw:function bjw(d){this.a=d},
bjx:function bjx(d){this.a=d},
Js:function Js(d,e){this.a=d
this.b=e},
ct4(d,e){return new A.Hf("HTTP request failed, statusCode: "+d+", "+e.j(0))},
aWb:function aWb(d,e){this.a=d
this.b=e},
Hf:function Hf(d){this.b=d},
ct9(d,e){var x=new A.a84(B.a([],y.v),B.a([],y.l),B.a([],y.u))
x.aES(d,e)
return x},
a84:function a84(d,e,f){var _=this
_.a=d
_.b=e
_.e=_.d=_.c=null
_.f=!1
_.r=0
_.w=!1
_.x=f},
aJn:function aJn(d,e){this.a=d
this.b=e},
pW(d,e,f,g,h,i){var x=null
return new D.Bd(G.c5K(x,x,new A.He(d,1,x,E.bM0)),e,i,h,x,C.dm,f,C.au,g,x)}},E,F,D,G
J=c[1]
B=c[0]
C=c[2]
A=a.updateHolder(c[34],A)
E=c[124]
F=c[178]
D=c[73]
G=c[70]
A.He.prototype={
rW(d){return new B.fn(this,y.i)},
vc(d,e){return A.cg1(this.EO(d,e),d.a,null)},
rV(d,e){return A.cg1(this.EO(d,e),d.a,null)},
EO(d,e){return this.aYh(d,e)},
aYh(d,e){var x=0,w=B.m(y.R),v,u=2,t=[],s=this,r,q,p,o,n
var $async$EO=B.n(function(f,g){if(f===1){t.push(g)
x=u}for(;;)switch(x){case 0:p=new A.aJ0(s,e,d)
o=new A.aJ1(s,d)
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
case 4:case 1:return B.k(v,w)
case 2:return B.j(t.at(-1),w)}})
return B.l($async$EO,w)},
FL(d){var x=0,w=B.m(y.p),v,u=this,t,s,r,q,p,o,n
var $async$FL=B.n(function(e,f){if(e===1)return B.j(f,w)
for(;;)switch(x){case 0:s=u.a
r=B.yR().a2(s)
q=new B.aI($.aZ,y.Z)
p=new B.bs(q,y.x)
o=A.cAZ()
o.open("GET",s,!0)
o.responseType="arraybuffer"
o.addEventListener("load",B.hU(new A.aIZ(o,p,r)))
o.addEventListener("error",B.hU(new A.aJ_(p,o,r)))
o.send()
x=3
return B.d(q,$async$FL)
case 3:s=o.response
s.toString
t=B.a7S(y.a.a(s),0,null)
if(t.byteLength===0)throw B.p(A.ct4(B.ao(o,"status"),r))
n=d
x=4
return B.d(B.Po(t),$async$FL)
case 4:v=n.$1(f)
x=1
break
case 1:return B.k(v,w)}})
return B.l($async$FL,w)},
m(d,e){var x=this
if(e==null)return!1
if(J.ay(e)!==B.a8(x))return!1
return e instanceof A.He&&e.a===x.a&&e.b===x.b&&e.d===x.d&&B.LZ(e.c,x.c)},
gC(d){var x=this
return B.ap(x.a,x.b,x.d,F.VE.iL(x.c),C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c)},
j(d){var x=this
return'NetworkImage("'+x.a+'", scale: '+C.k.M(x.b,1)+", webHtmlElementStrategy: "+x.d.b+", headers: "+B.h(x.c)+")"}}
A.agL.prototype={
aFc(d,e,f){var x=this
x.e=e
x.y.dL(new A.bjt(x),new A.bju(x,f),y.P)},
gatx(){var x=this,w=x.at
return w===$?x.at=new B.la(new A.bjv(x),new A.bjw(x),new A.bjx(x)):w},
a5V(){var x,w=this
if(w.z){x=w.Q
x===$&&B.b()
x.T(w.gatx())}w.as=!0
w.azM()}}
A.Js.prototype={
cg(){return new A.Js(this.a,this.b)},
n(){},
gdr(){return B.aq(B.cP("Could not create image data for this image because access to it is restricted by the Same-Origin Policy.\nSee https://developer.mozilla.org/en-US/docs/Web/Security/Same-origin_policy"))},
gjz(){return 1},
ga8Z(){var x=this.a
return C.i.H(4*x.naturalWidth*x.naturalHeight)},
$ijI:1,
goG(){return this.b}}
A.aWb.prototype={
O(){return"WebHtmlElementStrategy."+this.b}}
A.Hf.prototype={
j(d){return this.b},
$icp:1}
A.a84.prototype={
aES(d,e){d.dL(this.gayd(),new A.aJn(this,e),y.H)}}
var z=a.updateTypes([])
A.aJ0.prototype={
$0(){var x=0,w=B.m(y.R),v,u=this,t,s,r
var $async$$0=B.n(function(d,e){if(d===1)return B.j(e,w)
for(;;)switch(x){case 0:t=u.c
s=D
r=B
x=3
return B.d(u.a.FL(u.b),$async$$0)
case 3:v=s.QL(r.eb(e,y.p),t.a,null,t.b)
x=1
break
case 1:return B.k(v,w)}})
return B.l($async$$0,w)},
$S:273}
A.aJ1.prototype={
$0(){var x=0,w=B.m(y.R),v,u=this,t,s,r
var $async$$0=B.n(function(d,e){if(d===1)return B.j(e,w)
for(;;)switch(x){case 0:s=A.cB0()
r=u.b.a
s.src=r
x=3
return B.d(B.iJ(s.decode(),y.X),$async$$0)
case 3:t=A.ct9(B.eb(new A.Js(s,r),y.J),null)
t.e=r
v=t
x=1
break
case 1:return B.k(v,w)}})
return B.l($async$$0,w)},
$S:273}
A.aIZ.prototype={
$1(d){var x=this.a,w=x.status,v=w>=200&&w<300,u=w>307&&w<400,t=v||w===0||w===304||u,s=this.b
if(t)s.dJ(x)
else s.iE(new A.Hf("HTTP request failed, statusCode: "+B.h(w)+", "+this.c.j(0)))},
$S:34}
A.aJ_.prototype={
$1(d){return this.a.iE(new A.Hf("HTTP request failed, statusCode: "+B.h(this.b.status)+", "+this.c.j(0)))},
$S:7}
A.bjt.prototype={
$1(d){var x=this.a
x.z=!0
if(x.as){d.Gw()
return}x.Q!==$&&B.c_()
x.Q=d
d.a6(x.gatx())},
$S:784}
A.bju.prototype={
$2(d,e){this.a.z0(B.bY("resolving an image stream completer"),d,this.b,!0,e)},
$S:21}
A.bjv.prototype={
$2(d,e){this.a.WG(d)},
$S:785}
A.bjw.prototype={
$1(d){this.a.bpW(d)},
$S:786}
A.bjx.prototype={
$2(d,e){this.a.bpV(d,e)},
$S:135}
A.aJn.prototype={
$2(d,e){this.a.z0(B.bY("resolving a single-frame image stream"),d,this.b,!0,e)},
$S:21};(function inheritance(){var x=a.inherit,w=a.inheritMany
x(A.He,D.hO)
w(B.dX,[A.aJ0,A.aJ1])
w(B.d8,[A.aIZ,A.aJ_,A.bjt,A.bjw])
w(D.ka,[A.agL,A.a84])
w(B.em,[A.bju,A.bjv,A.bjx,A.aJn])
w(B.W,[A.Js,A.Hf])
x(A.aWb,B.fB)})()
B.dl(b.typeUniverse,JSON.parse('{"He":{"hO":["c58"],"hO.T":"c58"},"agL":{"ka":[]},"Js":{"jI":[]},"c58":{"hO":["c58"]},"Hf":{"cp":[]},"a84":{"ka":[]}}'))
var y=(function rtii(){var x=B.X
return{p:x("hI"),J:x("jI"),R:x("ka"),v:x("y<la>"),u:x("y<~()>"),l:x("y<~(W,du?)>"),a:x("rV"),P:x("bS"),i:x("fn<He>"),x:x("bs<bZ>"),Z:x("aI<bZ>"),X:x("W?"),H:x("~")}})();(function constants(){E.fm=new B.bz(45e6)
E.bM0=new A.aWb(0,"never")})()};
(a=>{a["7gOkaJ4So0mgfL9TFRM4nv2MWJY="]=a.current})($__dart_deferred_initializers__);