((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,B,C,G,F,A={
ds(d,e,f,g){var x=null
return new F.Hl(!0,f,x,x,x,g,x,x,!1,x,!0,x,new A.aiU(e,d,g,x,x),x)},
aiU:function aiU(d,e,f,g,h){var _=this
_.c=d
_.d=e
_.e=f
_.f=g
_.a=h},
czw(){return new b.G.XMLHttpRequest()},
czy(){return b.G.document.createElement("img")},
ceY(d,e,f){var x=new A.agL(d,B.a([],y.v),B.a([],y.l),B.a([],y.u))
x.aEy(d,e,f)
return x},
He:function He(d,e,f,g){var _=this
_.a=d
_.b=e
_.c=f
_.d=g},
aIP:function aIP(d,e,f){this.a=d
this.b=e
this.c=f},
aIQ:function aIQ(d,e){this.a=d
this.b=e},
aIN:function aIN(d,e,f){this.a=d
this.b=e
this.c=f},
aIO:function aIO(d,e,f){this.a=d
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
biD:function biD(d){this.a=d},
biE:function biE(d,e){this.a=d
this.b=e},
biF:function biF(d){this.a=d},
biG:function biG(d){this.a=d},
biH:function biH(d){this.a=d},
Js:function Js(d,e){this.a=d
this.b=e},
crJ(d,e){return new A.Hf("HTTP request failed, statusCode: "+d+", "+e.j(0))},
aW_:function aW_(d,e){this.a=d
this.b=e},
Hf:function Hf(d){this.b=d},
crN(d,e){var x=new A.a87(B.a([],y.v),B.a([],y.l),B.a([],y.u))
x.aEd(d,e)
return x},
a87:function a87(d,e,f){var _=this
_.a=d
_.b=e
_.e=_.d=_.c=null
_.f=!1
_.r=0
_.w=!1
_.x=f},
aJa:function aJa(d,e){this.a=d
this.b=e},
oo(d,e,f,g,h,i){var x=null
return new E.Ba(F.c4v(x,x,new A.He(d,1,x,D.bNT)),e,i,h,x,C.dh,f,C.an,g,x)}},D,E,H
J=c[1]
B=c[0]
C=c[2]
G=c[36]
F=c[30]
A=a.updateHolder(c[26],A)
D=c[55]
E=c[34]
H=c[71]
A.aiU.prototype={
E(d){var x,w=null,v=this.e,u=w
if(v==null)x=u
else{v=v.a
if(v==null)v=u
else{v=v.a0(C.dz)
v=v==null?w:v.r}x=v}if(x==null)x=14
v=B.bT(d,C.bJ)
v=v==null?w:v.gcf()
v=B.a1((v==null?C.bo:v).bd(x)/14,1,2)
F.cck(d)
v=B.aE(8,4,v-1)
v.toString
u=B.a([this.d,new B.dW(1,C.c3,this.c,w)],y.D)
return G.L(u,C.u,C.l,C.a1,v,w)}}
A.He.prototype={
rV(d){return new B.fg(this,y.i)},
vb(d,e){return A.ceY(this.Ev(d,e),d.a,null)},
rU(d,e){return A.ceY(this.Ev(d,e),d.a,null)},
Ev(d,e){return this.aXD(d,e)},
aXD(d,e){var x=0,w=B.m(y.R),v,u=2,t=[],s=this,r,q,p,o,n
var $async$Ev=B.n(function(f,g){if(f===1){t.push(g)
x=u}for(;;)switch(x){case 0:p=new A.aIP(s,e,d)
o=new A.aIQ(s,d)
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
return B.d(p.$0(),$async$Ev)
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
return B.l($async$Ev,w)},
Fr(d){var x=0,w=B.m(y.p),v,u=this,t,s,r,q,p,o,n
var $async$Fr=B.n(function(e,f){if(e===1)return B.j(f,w)
for(;;)switch(x){case 0:s=u.a
r=B.Dq().a0(s)
q=new B.aJ($.aV,y.Z)
p=new B.bn(q,y.x)
o=A.czw()
o.open("GET",s,!0)
o.responseType="arraybuffer"
o.addEventListener("load",B.hP(new A.aIN(o,p,r)))
o.addEventListener("error",B.hP(new A.aIO(p,o,r)))
o.send()
x=3
return B.d(q,$async$Fr)
case 3:s=o.response
s.toString
t=B.a7V(y.a.a(s),0,null)
if(t.byteLength===0)throw B.p(A.crJ(B.ap(o,"status"),r))
n=d
x=4
return B.d(B.Pj(t),$async$Fr)
case 4:v=n.$1(f)
x=1
break
case 1:return B.k(v,w)}})
return B.l($async$Fr,w)},
l(d,e){var x=this
if(e==null)return!1
if(J.ax(e)!==B.a7(x))return!1
return e instanceof A.He&&e.a===x.a&&e.b===x.b&&e.d===x.d&&B.LU(e.c,x.c)},
gD(d){var x=this
return B.aq(x.a,x.b,x.d,H.VV.iI(x.c),C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c)},
j(d){var x=this
return'NetworkImage("'+x.a+'", scale: '+C.k.N(x.b,1)+", webHtmlElementStrategy: "+x.d.b+", headers: "+B.h(x.c)+")"}}
A.agL.prototype={
aEy(d,e,f){var x=this
x.e=e
x.y.dL(new A.biD(x),new A.biE(x,f),y.P)},
gasV(){var x=this,w=x.at
return w===$?x.at=new B.l4(new A.biF(x),new A.biG(x),new A.biH(x)):w},
a5y(){var x,w=this
if(w.z){x=w.Q
x===$&&B.b()
x.S(w.gasV())}w.as=!0
w.az6()}}
A.Js.prototype={
cg(){return new A.Js(this.a,this.b)},
m(){},
gdq(){return B.an(B.cL("Could not create image data for this image because access to it is restricted by the Same-Origin Policy.\nSee https://developer.mozilla.org/en-US/docs/Web/Security/Same-origin_policy"))},
gju(){return 1},
ga8B(){var x=this.a
return C.i.J(4*x.naturalWidth*x.naturalHeight)},
$ijG:1,
goz(){return this.b}}
A.aW_.prototype={
O(){return"WebHtmlElementStrategy."+this.b}}
A.Hf.prototype={
j(d){return this.b},
$icm:1}
A.a87.prototype={
aEd(d,e){d.dL(this.gaxy(),new A.aJa(this,e),y.H)}}
var z=a.updateTypes([])
A.aIP.prototype={
$0(){var x=0,w=B.m(y.R),v,u=this,t,s,r
var $async$$0=B.n(function(d,e){if(d===1)return B.j(e,w)
for(;;)switch(x){case 0:t=u.c
s=E
r=B
x=3
return B.d(u.a.Fr(u.b),$async$$0)
case 3:v=s.QF(r.e5(e,y.p),t.a,null,t.b)
x=1
break
case 1:return B.k(v,w)}})
return B.l($async$$0,w)},
$S:253}
A.aIQ.prototype={
$0(){var x=0,w=B.m(y.R),v,u=this,t,s,r
var $async$$0=B.n(function(d,e){if(d===1)return B.j(e,w)
for(;;)switch(x){case 0:s=A.czy()
r=u.b.a
s.src=r
x=3
return B.d(B.iN(s.decode(),y.X),$async$$0)
case 3:t=A.crN(B.e5(new A.Js(s,r),y.J),null)
t.e=r
v=t
x=1
break
case 1:return B.k(v,w)}})
return B.l($async$$0,w)},
$S:253}
A.aIN.prototype={
$1(d){var x=this.a,w=x.status,v=w>=200&&w<300,u=w>307&&w<400,t=v||w===0||w===304||u,s=this.b
if(t)s.dJ(x)
else s.iD(new A.Hf("HTTP request failed, statusCode: "+B.h(w)+", "+this.c.j(0)))},
$S:35}
A.aIO.prototype={
$1(d){return this.a.iD(new A.Hf("HTTP request failed, statusCode: "+B.h(this.b.status)+", "+this.c.j(0)))},
$S:7}
A.biD.prototype={
$1(d){var x=this.a
x.z=!0
if(x.as){d.Ga()
return}x.Q!==$&&B.bZ()
x.Q=d
d.a8(x.gasV())},
$S:773}
A.biE.prototype={
$2(d,e){this.a.yP(B.bX("resolving an image stream completer"),d,this.b,!0,e)},
$S:21}
A.biF.prototype={
$2(d,e){this.a.Wg(d)},
$S:774}
A.biG.prototype={
$1(d){this.a.bp3(d)},
$S:775}
A.biH.prototype={
$2(d,e){this.a.bp2(d,e)},
$S:121}
A.aJa.prototype={
$2(d,e){this.a.yP(B.bX("resolving a single-frame image stream"),d,this.b,!0,e)},
$S:21};(function inheritance(){var x=a.inherit,w=a.inheritMany
x(A.aiU,B.ao)
x(A.He,E.hV)
w(B.hi,[A.aIP,A.aIQ])
w(B.eB,[A.aIN,A.aIO,A.biD,A.biG])
w(E.ka,[A.agL,A.a87])
w(B.hR,[A.biE,A.biF,A.biH,A.aJa])
w(B.X,[A.Js,A.Hf])
x(A.aW_,B.j8)})()
B.hy(b.typeUniverse,JSON.parse('{"aiU":{"ao":[],"f":[]},"He":{"hV":["c3U"],"hV.T":"c3U"},"agL":{"ka":[]},"Js":{"jG":[]},"c3U":{"hV":["c3U"]},"Hf":{"cm":[]},"a87":{"ka":[]}}'))
var y=(function rtii(){var x=B.ac
return{p:x("hE"),J:x("jG"),R:x("ka"),v:x("B<l4>"),D:x("B<f>"),u:x("B<~()>"),l:x("B<~(X,dg?)>"),a:x("rO"),P:x("bU"),i:x("fg<He>"),x:x("bn<bY>"),Z:x("aJ<bY>"),X:x("X?"),H:x("~")}})();(function constants(){D.fg=new B.bw(45e6)
D.e5=new B.bm(null,2,null,null)
D.bNT=new A.aW_(0,"never")})()};
(a=>{a["3YaE0ToZyd/2uW6RsQxboonBthU="]=a.current})($__dart_deferred_initializers__);