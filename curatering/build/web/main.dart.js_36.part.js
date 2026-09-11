((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,B,C,A={
cB_(){return new b.G.XMLHttpRequest()},
cB1(){return b.G.document.createElement("img")},
cg1(d,e,f){var x=new A.agJ(d,B.a([],y.v),B.a([],y.l),B.a([],y.u))
x.aFe(d,e,f)
return x},
Hc:function Hc(d,e,f,g){var _=this
_.a=d
_.b=e
_.c=f
_.d=g},
aIZ:function aIZ(d,e,f){this.a=d
this.b=e
this.c=f},
aJ_:function aJ_(d,e){this.a=d
this.b=e},
aIX:function aIX(d,e,f){this.a=d
this.b=e
this.c=f},
aIY:function aIY(d,e,f){this.a=d
this.b=e
this.c=f},
agJ:function agJ(d,e,f,g){var _=this
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
bjq:function bjq(d){this.a=d},
bjr:function bjr(d,e){this.a=d
this.b=e},
bjs:function bjs(d){this.a=d},
bjt:function bjt(d){this.a=d},
bju:function bju(d){this.a=d},
Jq:function Jq(d,e){this.a=d
this.b=e},
ct5(d,e){return new A.Hd("HTTP request failed, statusCode: "+d+", "+e.j(0))},
aW9:function aW9(d,e){this.a=d
this.b=e},
Hd:function Hd(d){this.b=d},
cta(d,e){var x=new A.a82(B.a([],y.v),B.a([],y.l),B.a([],y.u))
x.aEU(d,e)
return x},
a82:function a82(d,e,f){var _=this
_.a=d
_.b=e
_.e=_.d=_.c=null
_.f=!1
_.r=0
_.w=!1
_.x=f},
aJl:function aJl(d,e){this.a=d
this.b=e},
pX(d,e,f,g,h,i){var x=null
return new D.Bb(G.c5K(x,x,new A.Hc(d,1,x,E.bMz)),e,i,h,x,C.dj,f,C.ap,g,x)}},E,F,D,G
J=c[1]
B=c[0]
C=c[2]
A=a.updateHolder(c[34],A)
E=c[124]
F=c[178]
D=c[73]
G=c[70]
A.Hc.prototype={
rX(d){return new B.fn(this,y.i)},
vd(d,e){return A.cg1(this.EO(d,e),d.a,null)},
rW(d,e){return A.cg1(this.EO(d,e),d.a,null)},
EO(d,e){return this.aYk(d,e)},
aYk(d,e){var x=0,w=B.l(y.R),v,u=2,t=[],s=this,r,q,p,o,n
var $async$EO=B.m(function(f,g){if(f===1){t.push(g)
x=u}for(;;)switch(x){case 0:p=new A.aIZ(s,e,d)
o=new A.aJ_(s,d)
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
r=B.yR().a2(s)
q=new B.aI($.aX,y.Z)
p=new B.bq(q,y.x)
o=A.cB_()
o.open("GET",s,!0)
o.responseType="arraybuffer"
o.addEventListener("load",B.hV(new A.aIX(o,p,r)))
o.addEventListener("error",B.hV(new A.aIY(p,o,r)))
o.send()
x=3
return B.d(q,$async$FL)
case 3:s=o.response
s.toString
t=B.a7Q(y.a.a(s),0,null)
if(t.byteLength===0)throw B.p(A.ct5(B.ao(o,"status"),r))
n=d
x=4
return B.d(B.Pn(t),$async$FL)
case 4:v=n.$1(f)
x=1
break
case 1:return B.j(v,w)}})
return B.k($async$FL,w)},
m(d,e){var x=this
if(e==null)return!1
if(J.az(e)!==B.a8(x))return!1
return e instanceof A.Hc&&e.a===x.a&&e.b===x.b&&e.d===x.d&&B.LX(e.c,x.c)},
gC(d){var x=this
return B.ap(x.a,x.b,x.d,F.VK.iM(x.c),C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c)},
j(d){var x=this
return'NetworkImage("'+x.a+'", scale: '+C.k.M(x.b,1)+", webHtmlElementStrategy: "+x.d.b+", headers: "+B.h(x.c)+")"}}
A.agJ.prototype={
aFe(d,e,f){var x=this
x.e=e
x.y.dL(new A.bjq(x),new A.bjr(x,f),y.P)},
gatz(){var x=this,w=x.at
return w===$?x.at=new B.la(new A.bjs(x),new A.bjt(x),new A.bju(x)):w},
a5W(){var x,w=this
if(w.z){x=w.Q
x===$&&B.b()
x.T(w.gatz())}w.as=!0
w.azO()}}
A.Jq.prototype={
cg(){return new A.Jq(this.a,this.b)},
n(){},
gdr(){return B.aq(B.cP("Could not create image data for this image because access to it is restricted by the Same-Origin Policy.\nSee https://developer.mozilla.org/en-US/docs/Web/Security/Same-origin_policy"))},
gjA(){return 1},
ga9_(){var x=this.a
return C.i.H(4*x.naturalWidth*x.naturalHeight)},
$ijI:1,
goH(){return this.b}}
A.aW9.prototype={
O(){return"WebHtmlElementStrategy."+this.b}}
A.Hd.prototype={
j(d){return this.b},
$ics:1}
A.a82.prototype={
aEU(d,e){d.dL(this.gayf(),new A.aJl(this,e),y.H)}}
var z=a.updateTypes([])
A.aIZ.prototype={
$0(){var x=0,w=B.l(y.R),v,u=this,t,s,r
var $async$$0=B.m(function(d,e){if(d===1)return B.i(e,w)
for(;;)switch(x){case 0:t=u.c
s=D
r=B
x=3
return B.d(u.a.FL(u.b),$async$$0)
case 3:v=s.QJ(r.ec(e,y.p),t.a,null,t.b)
x=1
break
case 1:return B.j(v,w)}})
return B.k($async$$0,w)},
$S:321}
A.aJ_.prototype={
$0(){var x=0,w=B.l(y.R),v,u=this,t,s,r
var $async$$0=B.m(function(d,e){if(d===1)return B.i(e,w)
for(;;)switch(x){case 0:s=A.cB1()
r=u.b.a
s.src=r
x=3
return B.d(B.iJ(s.decode(),y.X),$async$$0)
case 3:t=A.cta(B.ec(new A.Jq(s,r),y.J),null)
t.e=r
v=t
x=1
break
case 1:return B.j(v,w)}})
return B.k($async$$0,w)},
$S:321}
A.aIX.prototype={
$1(d){var x=this.a,w=x.status,v=w>=200&&w<300,u=w>307&&w<400,t=v||w===0||w===304||u,s=this.b
if(t)s.dJ(x)
else s.iF(new A.Hd("HTTP request failed, statusCode: "+B.h(w)+", "+this.c.j(0)))},
$S:34}
A.aIY.prototype={
$1(d){return this.a.iF(new A.Hd("HTTP request failed, statusCode: "+B.h(this.b.status)+", "+this.c.j(0)))},
$S:7}
A.bjq.prototype={
$1(d){var x=this.a
x.z=!0
if(x.as){d.Gx()
return}x.Q!==$&&B.c_()
x.Q=d
d.a6(x.gatz())},
$S:783}
A.bjr.prototype={
$2(d,e){this.a.z1(B.bY("resolving an image stream completer"),d,this.b,!0,e)},
$S:21}
A.bjs.prototype={
$2(d,e){this.a.WH(d)},
$S:784}
A.bjt.prototype={
$1(d){this.a.bpY(d)},
$S:785}
A.bju.prototype={
$2(d,e){this.a.bpX(d,e)},
$S:126}
A.aJl.prototype={
$2(d,e){this.a.z1(B.bY("resolving a single-frame image stream"),d,this.b,!0,e)},
$S:21};(function inheritance(){var x=a.inherit,w=a.inheritMany
x(A.Hc,D.hO)
w(B.dY,[A.aIZ,A.aJ_])
w(B.d9,[A.aIX,A.aIY,A.bjq,A.bjt])
w(D.ka,[A.agJ,A.a82])
w(B.en,[A.bjr,A.bjs,A.bju,A.aJl])
w(B.W,[A.Jq,A.Hd])
x(A.aW9,B.fB)})()
B.dl(b.typeUniverse,JSON.parse('{"Hc":{"hO":["c58"],"hO.T":"c58"},"agJ":{"ka":[]},"Jq":{"jI":[]},"c58":{"hO":["c58"]},"Hd":{"cs":[]},"a82":{"ka":[]}}'))
var y=(function rtii(){var x=B.X
return{p:x("hI"),J:x("jI"),R:x("ka"),v:x("y<la>"),u:x("y<~()>"),l:x("y<~(W,du?)>"),a:x("rU"),P:x("bR"),i:x("fn<Hc>"),x:x("bq<bZ>"),Z:x("aI<bZ>"),X:x("W?"),H:x("~")}})();(function constants(){E.fm=new B.by(45e6)
E.bMz=new A.aW9(0,"never")})()};
(a=>{a["lN2ih90aMW9G8QEYyTuauztmkKI="]=a.current})($__dart_deferred_initializers__);