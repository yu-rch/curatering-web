((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,B,C,A={
cB_(){return new b.G.XMLHttpRequest()},
cB1(){return b.G.document.createElement("img")},
cg2(d,e,f){var x=new A.agL(d,B.a([],y.v),B.a([],y.l),B.a([],y.u))
x.aFd(d,e,f)
return x},
Hc:function Hc(d,e,f,g){var _=this
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
bjw:function bjw(d){this.a=d},
bjx:function bjx(d,e){this.a=d
this.b=e},
bjy:function bjy(d){this.a=d},
bjz:function bjz(d){this.a=d},
bjA:function bjA(d){this.a=d},
Jq:function Jq(d,e){this.a=d
this.b=e},
ct5(d,e){return new A.Hd("HTTP request failed, statusCode: "+d+", "+e.j(0))},
aWb:function aWb(d,e){this.a=d
this.b=e},
Hd:function Hd(d){this.b=d},
cta(d,e){var x=new A.a84(B.a([],y.v),B.a([],y.l),B.a([],y.u))
x.aET(d,e)
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
os(d,e,f,g,h,i){var x=null
return new D.Bd(G.c5M(x,x,new A.Hc(d,1,x,E.bLZ)),e,i,h,x,C.dm,f,C.ar,g,x)}},E,F,D,G
J=c[1]
B=c[0]
C=c[2]
A=a.updateHolder(c[40],A)
E=c[136]
F=c[199]
D=c[82]
G=c[79]
A.Hc.prototype={
rX(d){return new B.fn(this,y.i)},
vc(d,e){return A.cg2(this.EO(d,e),d.a,null)},
rW(d,e){return A.cg2(this.EO(d,e),d.a,null)},
EO(d,e){return this.aYj(d,e)},
aYj(d,e){var x=0,w=B.m(y.R),v,u=2,t=[],s=this,r,q,p,o,n
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
o=A.cB_()
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
if(t.byteLength===0)throw B.p(A.ct5(B.ao(o,"status"),r))
n=d
x=4
return B.d(B.Pn(t),$async$FL)
case 4:v=n.$1(f)
x=1
break
case 1:return B.k(v,w)}})
return B.l($async$FL,w)},
m(d,e){var x=this
if(e==null)return!1
if(J.ay(e)!==B.a8(x))return!1
return e instanceof A.Hc&&e.a===x.a&&e.b===x.b&&e.d===x.d&&B.LX(e.c,x.c)},
gC(d){var x=this
return B.ap(x.a,x.b,x.d,F.VF.iL(x.c),C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c)},
j(d){var x=this
return'NetworkImage("'+x.a+'", scale: '+C.k.M(x.b,1)+", webHtmlElementStrategy: "+x.d.b+", headers: "+B.h(x.c)+")"}}
A.agL.prototype={
aFd(d,e,f){var x=this
x.e=e
x.y.dL(new A.bjw(x),new A.bjx(x,f),y.P)},
gaty(){var x=this,w=x.at
return w===$?x.at=new B.la(new A.bjy(x),new A.bjz(x),new A.bjA(x)):w},
a5V(){var x,w=this
if(w.z){x=w.Q
x===$&&B.b()
x.T(w.gaty())}w.as=!0
w.azN()}}
A.Jq.prototype={
cg(){return new A.Jq(this.a,this.b)},
n(){},
gdr(){return B.aq(B.cP("Could not create image data for this image because access to it is restricted by the Same-Origin Policy.\nSee https://developer.mozilla.org/en-US/docs/Web/Security/Same-origin_policy"))},
gjz(){return 1},
ga8Z(){var x=this.a
return C.i.H(4*x.naturalWidth*x.naturalHeight)},
$ijI:1,
goH(){return this.b}}
A.aWb.prototype={
O(){return"WebHtmlElementStrategy."+this.b}}
A.Hd.prototype={
j(d){return this.b},
$icp:1}
A.a84.prototype={
aET(d,e){d.dL(this.gaye(),new A.aJn(this,e),y.H)}}
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
$S:322}
A.aJ1.prototype={
$0(){var x=0,w=B.m(y.R),v,u=this,t,s,r
var $async$$0=B.n(function(d,e){if(d===1)return B.j(e,w)
for(;;)switch(x){case 0:s=A.cB1()
r=u.b.a
s.src=r
x=3
return B.d(B.iJ(s.decode(),y.X),$async$$0)
case 3:t=A.cta(B.eb(new A.Jq(s,r),y.J),null)
t.e=r
v=t
x=1
break
case 1:return B.k(v,w)}})
return B.l($async$$0,w)},
$S:322}
A.aIZ.prototype={
$1(d){var x=this.a,w=x.status,v=w>=200&&w<300,u=w>307&&w<400,t=v||w===0||w===304||u,s=this.b
if(t)s.dJ(x)
else s.iF(new A.Hd("HTTP request failed, statusCode: "+B.h(w)+", "+this.c.j(0)))},
$S:37}
A.aJ_.prototype={
$1(d){return this.a.iF(new A.Hd("HTTP request failed, statusCode: "+B.h(this.b.status)+", "+this.c.j(0)))},
$S:7}
A.bjw.prototype={
$1(d){var x=this.a
x.z=!0
if(x.as){d.Gw()
return}x.Q!==$&&B.c0()
x.Q=d
d.a6(x.gaty())},
$S:782}
A.bjx.prototype={
$2(d,e){this.a.z0(B.bZ("resolving an image stream completer"),d,this.b,!0,e)},
$S:20}
A.bjy.prototype={
$2(d,e){this.a.WF(d)},
$S:783}
A.bjz.prototype={
$1(d){this.a.bpZ(d)},
$S:784}
A.bjA.prototype={
$2(d,e){this.a.bpY(d,e)},
$S:126}
A.aJn.prototype={
$2(d,e){this.a.z0(B.bZ("resolving a single-frame image stream"),d,this.b,!0,e)},
$S:20};(function inheritance(){var x=a.inherit,w=a.inheritMany
x(A.Hc,D.hO)
w(B.dP,[A.aJ0,A.aJ1])
w(B.d0,[A.aIZ,A.aJ_,A.bjw,A.bjz])
w(D.ka,[A.agL,A.a84])
w(B.ei,[A.bjx,A.bjy,A.bjA,A.aJn])
w(B.X,[A.Jq,A.Hd])
x(A.aWb,B.fw)})()
B.dd(b.typeUniverse,JSON.parse('{"Hc":{"hO":["c5a"],"hO.T":"c5a"},"agL":{"ka":[]},"Jq":{"jI":[]},"c5a":{"hO":["c5a"]},"Hd":{"cp":[]},"a84":{"ka":[]}}'))
var y=(function rtii(){var x=B.W
return{p:x("hI"),J:x("jI"),R:x("ka"),v:x("y<la>"),u:x("y<~()>"),l:x("y<~(X,du?)>"),a:x("rU"),P:x("bS"),i:x("fn<Hc>"),x:x("bs<c_>"),Z:x("aI<c_>"),X:x("X?"),H:x("~")}})();(function constants(){E.fm=new B.bz(45e6)
E.bLZ=new A.aWb(0,"never")})()};
(a=>{a["r7hk6cQ76uTaZBaWqzfy5MSPJgU="]=a.current})($__dart_deferred_initializers__);