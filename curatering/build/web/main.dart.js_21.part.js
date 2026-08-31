((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,B,C,F,D,G,A={
dB(d,e,f,g){var x=null
return new D.I2(!0,f,x,x,x,g,x,x,!1,x,!0,x,new A.akR(e,d,g,x,x),x)},
akR:function akR(d,e,f,g,h){var _=this
_.c=d
_.d=e
_.e=f
_.f=g
_.a=h},
cCv(){return new b.G.XMLHttpRequest()},
cCx(){return b.G.document.createElement("img")},
chJ(d,e,f){var x=new A.aiv(d,B.a([],y.v),B.a([],y.l),B.a([],y.u))
x.aEG(d,e,f)
return x},
HW:function HW(d,e,f,g){var _=this
_.a=d
_.b=e
_.c=f
_.d=g},
aLj:function aLj(d,e,f){this.a=d
this.b=e
this.c=f},
aLk:function aLk(d,e){this.a=d
this.b=e},
aLh:function aLh(d,e,f){this.a=d
this.b=e
this.c=f},
aLi:function aLi(d,e,f){this.a=d
this.b=e
this.c=f},
aiv:function aiv(d,e,f,g){var _=this
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
bla:function bla(d){this.a=d},
blb:function blb(d,e){this.a=d
this.b=e},
blc:function blc(d){this.a=d},
bld:function bld(d){this.a=d},
ble:function ble(d){this.a=d},
Kb:function Kb(d,e){this.a=d
this.b=e},
cuG(d,e){return new A.HX("HTTP request failed, statusCode: "+d+", "+e.j(0))},
aYy:function aYy(d,e){this.a=d
this.b=e},
HX:function HX(d){this.b=d},
cuK(d,e){var x=new A.a9p(B.a([],y.v),B.a([],y.l),B.a([],y.u))
x.aEl(d,e)
return x},
a9p:function a9p(d,e,f){var _=this
_.a=d
_.b=e
_.e=_.d=_.c=null
_.f=!1
_.r=0
_.w=!1
_.x=f},
aLF:function aLF(d,e){this.a=d
this.b=e},
oT(d,e,f,g,h,i){var x=null
return new D.BO(D.c77(x,x,new A.HW(d,1,x,E.bNU)),e,i,h,x,C.dh,f,C.ao,g,x)}},E
J=c[1]
B=c[0]
C=c[2]
F=c[25]
D=c[23]
G=c[31]
A=a.updateHolder(c[21],A)
E=c[38]
A.akR.prototype={
F(d){var x,w=null,v=this.e,u=w
if(v==null)x=u
else{v=v.a
if(v==null)v=u
else{v=v.a_(C.dz)
v=v==null?w:v.r}x=v}if(x==null)x=14
v=B.c_(d,C.bJ)
v=v==null?w:v.gcf()
v=B.a3((v==null?C.bo:v).bd(0,x)/14,1,2)
D.cf4(d)
v=B.aJ(8,4,v-1)
v.toString
u=B.a([this.d,new B.e6(1,C.c3,this.c,w)],y.D)
return F.L(u,C.u,C.l,C.a1,v,w)}}
A.HW.prototype={
rW(d){return new B.ft(this,y.i)},
vb(d,e){return A.chJ(this.Eu(d,e),d.a,null)},
rV(d,e){return A.chJ(this.Eu(d,e),d.a,null)},
Eu(d,e){return this.aXP(d,e)},
aXP(d,e){var x=0,w=B.o(y.R),v,u=2,t=[],s=this,r,q,p,o,n
var $async$Eu=B.p(function(f,g){if(f===1){t.push(g)
x=u}for(;;)switch(x){case 0:p=new A.aLj(s,e,d)
o=new A.aLk(s,d)
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
return B.d(p.$0(),$async$Eu)
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
return B.n($async$Eu,w)},
Fq(d){var x=0,w=B.o(y.p),v,u=this,t,s,r,q,p,o,n
var $async$Fq=B.p(function(e,f){if(e===1)return B.l(f,w)
for(;;)switch(x){case 0:s=u.a
r=B.E4().a_(s)
q=new B.aN($.b0,y.Z)
p=new B.bu(q,y.x)
o=A.cCv()
o.open("GET",s,!0)
o.responseType="arraybuffer"
o.addEventListener("load",B.iu(new A.aLh(o,p,r)))
o.addEventListener("error",B.iu(new A.aLi(p,o,r)))
o.send()
x=3
return B.d(q,$async$Fq)
case 3:s=o.response
s.toString
t=B.a9a(y.a.a(s),0,null)
if(t.byteLength===0)throw B.j(A.cuG(B.ar(o,"status"),r))
n=d
x=4
return B.d(B.Q9(t),$async$Fq)
case 4:v=n.$1(f)
x=1
break
case 1:return B.m(v,w)}})
return B.n($async$Fq,w)},
l(d,e){var x=this
if(e==null)return!1
if(J.az(e)!==B.a9(x))return!1
return e instanceof A.HW&&e.a===x.a&&e.b===x.b&&e.d===x.d&&B.MF(e.c,x.c)},
gD(d){var x=this
return B.aq(x.a,x.b,x.d,G.VX.iH(0,x.c),C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c)},
j(d){var x=this
return'NetworkImage("'+x.a+'", scale: '+C.k.N(x.b,1)+", webHtmlElementStrategy: "+x.d.b+", headers: "+B.i(x.c)+")"}}
A.aiv.prototype={
aEG(d,e,f){var x=this
x.e=e
x.y.dK(new A.bla(x),new A.blb(x,f),y.P)},
gat1(d){var x=this,w=x.at
return w===$?x.at=new B.li(new A.blc(x),new A.bld(x),new A.ble(x)):w},
a5C(){var x,w=this
if(w.z){x=w.Q
x===$&&B.b()
x.S(0,w.gat1(0))}w.as=!0
w.azd()}}
A.Kb.prototype={
cg(d){return new A.Kb(this.a,this.b)},
m(){},
ge1(d){return B.ao(B.b8("Could not create image data for this image because access to it is restricted by the Same-Origin Policy.\nSee https://developer.mozilla.org/en-US/docs/Web/Security/Same-origin_policy"))},
gju(d){return 1},
ga8G(){var x=this.a
return C.i.J(4*x.naturalWidth*x.naturalHeight)},
$ijP:1,
gox(){return this.b}}
A.aYy.prototype={
O(){return"WebHtmlElementStrategy."+this.b}}
A.HX.prototype={
j(d){return this.b},
$ict:1}
A.a9p.prototype={
aEl(d,e){d.dK(this.gaxF(),new A.aLF(this,e),y.H)}}
var z=a.updateTypes([])
A.aLj.prototype={
$0(){var x=0,w=B.o(y.R),v,u=this,t,s,r
var $async$$0=B.p(function(d,e){if(d===1)return B.l(e,w)
for(;;)switch(x){case 0:t=u.c
s=D
r=B
x=3
return B.d(u.a.Fq(u.b),$async$$0)
case 3:v=s.Rt(r.eg(e,y.p),t.a,null,t.b)
x=1
break
case 1:return B.m(v,w)}})
return B.n($async$$0,w)},
$S:314}
A.aLk.prototype={
$0(){var x=0,w=B.o(y.R),v,u=this,t,s,r
var $async$$0=B.p(function(d,e){if(d===1)return B.l(e,w)
for(;;)switch(x){case 0:s=A.cCx()
r=u.b.a
s.src=r
x=3
return B.d(B.iw(s.decode(),y.X),$async$$0)
case 3:t=A.cuK(B.eg(new A.Kb(s,r),y.J),null)
t.e=r
v=t
x=1
break
case 1:return B.m(v,w)}})
return B.n($async$$0,w)},
$S:314}
A.aLh.prototype={
$1(d){var x=this.a,w=x.status,v=w>=200&&w<300,u=w>307&&w<400,t=v||w===0||w===304||u,s=this.b
if(t)s.dI(0,x)
else s.iZ(new A.HX("HTTP request failed, statusCode: "+B.i(w)+", "+this.c.j(0)))},
$S:40}
A.aLi.prototype={
$1(d){return this.a.iZ(new A.HX("HTTP request failed, statusCode: "+B.i(this.b.status)+", "+this.c.j(0)))},
$S:7}
A.bla.prototype={
$1(d){var x=this.a
x.z=!0
if(x.as){d.Ga()
return}x.Q!==$&&B.c5()
x.Q=d
d.a9(0,x.gat1(0))},
$S:776}
A.blb.prototype={
$2(d,e){this.a.yQ(B.c3("resolving an image stream completer"),d,this.b,!0,e)},
$S:21}
A.blc.prototype={
$2(d,e){this.a.Wi(d)},
$S:777}
A.bld.prototype={
$1(d){this.a.bpe(d)},
$S:778}
A.ble.prototype={
$2(d,e){this.a.bpd(d,e)},
$S:128}
A.aLF.prototype={
$2(d,e){this.a.yQ(B.c3("resolving a single-frame image stream"),d,this.b,!0,e)},
$S:21};(function inheritance(){var x=a.inherit,w=a.inheritMany
x(A.akR,B.as)
x(A.HW,D.ik)
w(B.jm,[A.aLj,A.aLk])
w(B.fK,[A.aLh,A.aLi,A.bla,A.bld])
w(D.km,[A.aiv,A.a9p])
w(B.jJ,[A.blb,A.blc,A.ble,A.aLF])
w(B.a1,[A.Kb,A.HX])
x(A.aYy,B.lw)})()
B.k6(b.typeUniverse,JSON.parse('{"akR":{"as":[],"f":[]},"HW":{"ik":["c6w"],"ik.T":"c6w"},"aiv":{"km":[]},"Kb":{"jP":[]},"c6w":{"ik":["c6w"]},"HX":{"ct":[]},"a9p":{"km":[]}}'))
var y=(function rtii(){var x=B.aj
return{p:x("hL"),J:x("jP"),R:x("km"),v:x("B<li>"),D:x("B<f>"),u:x("B<~()>"),l:x("B<~(a1,dn?)>"),a:x("tk"),P:x("c4"),i:x("ft<HW>"),x:x("bu<aE>"),Z:x("aN<aE>"),X:x("a1?"),H:x("~")}})();(function constants(){E.fg=new B.bC(45e6)
E.e5=new B.bt(null,2,null,null)
E.bNU=new A.aYy(0,"never")})()};
(a=>{a["uTzW25X9LGUy5n6lDysmQkvlkrU="]=a.current})($__dart_deferred_initializers__);