((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,B,C,G,F,A={
dB(d,e,f,g){var x=null
return new F.I7(!0,f,x,x,x,g,x,x,!1,x,!0,x,new A.akW(e,d,g,x,x),x)},
akW:function akW(d,e,f,g,h){var _=this
_.c=d
_.d=e
_.e=f
_.f=g
_.a=h},
cCO(){return new b.G.XMLHttpRequest()},
cCQ(){return b.G.document.createElement("img")},
chX(d,e,f){var x=new A.aiz(d,B.a([],y.v),B.a([],y.l),B.a([],y.u))
x.aEG(d,e,f)
return x},
I0:function I0(d,e,f,g){var _=this
_.a=d
_.b=e
_.c=f
_.d=g},
aLo:function aLo(d,e,f){this.a=d
this.b=e
this.c=f},
aLp:function aLp(d,e){this.a=d
this.b=e},
aLm:function aLm(d,e,f){this.a=d
this.b=e
this.c=f},
aLn:function aLn(d,e,f){this.a=d
this.b=e
this.c=f},
aiz:function aiz(d,e,f,g){var _=this
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
blh:function blh(d){this.a=d},
bli:function bli(d,e){this.a=d
this.b=e},
blj:function blj(d){this.a=d},
blk:function blk(d){this.a=d},
bll:function bll(d){this.a=d},
Kg:function Kg(d,e){this.a=d
this.b=e},
cuV(d,e){return new A.I1("HTTP request failed, statusCode: "+d+", "+e.j(0))},
aYE:function aYE(d,e){this.a=d
this.b=e},
I1:function I1(d){this.b=d},
cuZ(d,e){var x=new A.a9u(B.a([],y.v),B.a([],y.l),B.a([],y.u))
x.aEl(d,e)
return x},
a9u:function a9u(d,e,f){var _=this
_.a=d
_.b=e
_.e=_.d=_.c=null
_.f=!1
_.r=0
_.w=!1
_.x=f},
aLK:function aLK(d,e){this.a=d
this.b=e},
oU(d,e,f,g,h,i){var x=null
return new E.BT(F.c7k(x,x,new A.I0(d,1,x,D.bNY)),e,i,h,x,C.dh,f,C.an,g,x)}},D,E,H
J=c[1]
B=c[0]
C=c[2]
G=c[36]
F=c[30]
A=a.updateHolder(c[26],A)
D=c[55]
E=c[34]
H=c[71]
A.akW.prototype={
G(d){var x,w=null,v=this.e,u=w
if(v==null)x=u
else{v=v.a
if(v==null)v=u
else{v=v.a_(C.dz)
v=v==null?w:v.r}x=v}if(x==null)x=14
v=B.c_(d,C.bJ)
v=v==null?w:v.gcf()
v=B.a3((v==null?C.bo:v).bd(0,x)/14,1,2)
F.cfi(d)
v=B.aJ(8,4,v-1)
v.toString
u=B.a([this.d,new B.e6(1,C.c3,this.c,w)],y.D)
return G.M(u,C.u,C.l,C.a1,v,w)}}
A.I0.prototype={
rW(d){return new B.fu(this,y.i)},
vb(d,e){return A.chX(this.Et(d,e),d.a,null)},
rV(d,e){return A.chX(this.Et(d,e),d.a,null)},
Et(d,e){return this.aXP(d,e)},
aXP(d,e){var x=0,w=B.o(y.R),v,u=2,t=[],s=this,r,q,p,o,n
var $async$Et=B.p(function(f,g){if(f===1){t.push(g)
x=u}for(;;)switch(x){case 0:p=new A.aLo(s,e,d)
o=new A.aLp(s,d)
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
return B.e(p.$0(),$async$Et)
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
case 4:case 1:return B.m(v,w)
case 2:return B.l(t.at(-1),w)}})
return B.n($async$Et,w)},
Fp(d){var x=0,w=B.o(y.p),v,u=this,t,s,r,q,p,o,n
var $async$Fp=B.p(function(e,f){if(e===1)return B.l(f,w)
for(;;)switch(x){case 0:s=u.a
r=B.E8().a_(s)
q=new B.aN($.b0,y.Z)
p=new B.bu(q,y.x)
o=A.cCO()
o.open("GET",s,!0)
o.responseType="arraybuffer"
o.addEventListener("load",B.iA(new A.aLm(o,p,r)))
o.addEventListener("error",B.iA(new A.aLn(p,o,r)))
o.send()
x=3
return B.e(q,$async$Fp)
case 3:s=o.response
s.toString
t=B.a9f(y.a.a(s),0,null)
if(t.byteLength===0)throw B.j(A.cuV(B.as(o,"status"),r))
n=d
x=4
return B.e(B.Qd(t),$async$Fp)
case 4:v=n.$1(f)
x=1
break
case 1:return B.m(v,w)}})
return B.n($async$Fp,w)},
l(d,e){var x=this
if(e==null)return!1
if(J.aA(e)!==B.a9(x))return!1
return e instanceof A.I0&&e.a===x.a&&e.b===x.b&&e.d===x.d&&B.MI(e.c,x.c)},
gD(d){var x=this
return B.ar(x.a,x.b,x.d,H.W_.iH(0,x.c),C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c)},
j(d){var x=this
return'NetworkImage("'+x.a+'", scale: '+C.k.N(x.b,1)+", webHtmlElementStrategy: "+x.d.b+", headers: "+B.i(x.c)+")"}}
A.aiz.prototype={
aEG(d,e,f){var x=this
x.e=e
x.y.dK(new A.blh(x),new A.bli(x,f),y.P)},
gat1(d){var x=this,w=x.at
return w===$?x.at=new B.lk(new A.blj(x),new A.blk(x),new A.bll(x)):w},
a5B(){var x,w=this
if(w.z){x=w.Q
x===$&&B.b()
x.S(0,w.gat1(0))}w.as=!0
w.azd()}}
A.Kg.prototype={
cg(d){return new A.Kg(this.a,this.b)},
m(){},
ge1(d){return B.ao(B.b9("Could not create image data for this image because access to it is restricted by the Same-Origin Policy.\nSee https://developer.mozilla.org/en-US/docs/Web/Security/Same-origin_policy"))},
gju(d){return 1},
ga8F(){var x=this.a
return C.i.J(4*x.naturalWidth*x.naturalHeight)},
$ijT:1,
gox(){return this.b}}
A.aYE.prototype={
O(){return"WebHtmlElementStrategy."+this.b}}
A.I1.prototype={
j(d){return this.b},
$ict:1}
A.a9u.prototype={
aEl(d,e){d.dK(this.gaxF(),new A.aLK(this,e),y.H)}}
var z=a.updateTypes([])
A.aLo.prototype={
$0(){var x=0,w=B.o(y.R),v,u=this,t,s,r
var $async$$0=B.p(function(d,e){if(d===1)return B.l(e,w)
for(;;)switch(x){case 0:t=u.c
s=E
r=B
x=3
return B.e(u.a.Fp(u.b),$async$$0)
case 3:v=s.Rx(r.eg(e,y.p),t.a,null,t.b)
x=1
break
case 1:return B.m(v,w)}})
return B.n($async$$0,w)},
$S:262}
A.aLp.prototype={
$0(){var x=0,w=B.o(y.R),v,u=this,t,s,r
var $async$$0=B.p(function(d,e){if(d===1)return B.l(e,w)
for(;;)switch(x){case 0:s=A.cCQ()
r=u.b.a
s.src=r
x=3
return B.e(B.iC(s.decode(),y.X),$async$$0)
case 3:t=A.cuZ(B.eg(new A.Kg(s,r),y.J),null)
t.e=r
v=t
x=1
break
case 1:return B.m(v,w)}})
return B.n($async$$0,w)},
$S:262}
A.aLm.prototype={
$1(d){var x=this.a,w=x.status,v=w>=200&&w<300,u=w>307&&w<400,t=v||w===0||w===304||u,s=this.b
if(t)s.dI(0,x)
else s.iZ(new A.I1("HTTP request failed, statusCode: "+B.i(w)+", "+this.c.j(0)))},
$S:40}
A.aLn.prototype={
$1(d){return this.a.iZ(new A.I1("HTTP request failed, statusCode: "+B.i(this.b.status)+", "+this.c.j(0)))},
$S:7}
A.blh.prototype={
$1(d){var x=this.a
x.z=!0
if(x.as){d.G8()
return}x.Q!==$&&B.c5()
x.Q=d
d.a9(0,x.gat1(0))},
$S:774}
A.bli.prototype={
$2(d,e){this.a.yP(B.c4("resolving an image stream completer"),d,this.b,!0,e)},
$S:21}
A.blj.prototype={
$2(d,e){this.a.Wh(d)},
$S:775}
A.blk.prototype={
$1(d){this.a.bpi(d)},
$S:776}
A.bll.prototype={
$2(d,e){this.a.bph(d,e)},
$S:131}
A.aLK.prototype={
$2(d,e){this.a.yP(B.c4("resolving a single-frame image stream"),d,this.b,!0,e)},
$S:21};(function inheritance(){var x=a.inherit,w=a.inheritMany
x(A.akW,B.aq)
x(A.I0,E.i6)
w(B.hw,[A.aLo,A.aLp])
w(B.eQ,[A.aLm,A.aLn,A.blh,A.blk])
w(E.ko,[A.aiz,A.a9u])
w(B.i2,[A.bli,A.blj,A.bll,A.aLK])
w(B.Y,[A.Kg,A.I1])
x(A.aYE,B.jl)})()
B.hL(b.typeUniverse,JSON.parse('{"akW":{"aq":[],"f":[]},"I0":{"i6":["c6J"],"i6.T":"c6J"},"aiz":{"ko":[]},"Kg":{"jT":[]},"c6J":{"i6":["c6J"]},"I1":{"ct":[]},"a9u":{"ko":[]}}'))
var y=(function rtii(){var x=B.ae
return{p:x("hP"),J:x("jT"),R:x("ko"),v:x("B<lk>"),D:x("B<f>"),u:x("B<~()>"),l:x("B<~(Y,dn?)>"),a:x("tm"),P:x("c0"),i:x("fu<I0>"),x:x("bu<aE>"),Z:x("aN<aE>"),X:x("Y?"),H:x("~")}})();(function constants(){D.fg=new B.bD(45e6)
D.e5=new B.bt(null,2,null,null)
D.bNY=new A.aYE(0,"never")})()};
(a=>{a["RF3fmPH+BgG9pUOPDrq1GWLATVk="]=a.current})($__dart_deferred_initializers__);