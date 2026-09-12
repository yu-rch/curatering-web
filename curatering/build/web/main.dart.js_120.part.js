((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,A,C,F,B={le:function le(d,e,f,g,h){var _=this
_.a=d
_.b=e
_.c=f
_.d=g
_.e=h},jl:function jl(d,e,f,g,h,i,j){var _=this
_.a=d
_.b=e
_.c=f
_.d=g
_.e=h
_.f=i
_.r=j},a7g:function a7g(d,e,f){var _=this
_.a=d
_.b=e
_.c=!1
_.I$=0
_.J$=f
_.aN$=_.aJ$=0},aEt:function aEt(){},aEv:function aEv(){},aEh:function aEh(){},aEi:function aEi(){},aEj:function aEj(){},aEk:function aEk(){},aEl:function aEl(){},aEm:function aEm(){},aEw:function aEw(d){this.a=d},aEn:function aEn(d){this.a=d},aEx:function aEx(d){this.a=d},aEo:function aEo(d){this.a=d},aEp:function aEp(d){this.a=d},aEq:function aEq(d){this.a=d},aEr:function aEr(){},aEs:function aEs(){},aEu:function aEu(d){this.a=d},
c4i(d,e,f,g){return new B.a4L(d,f,g,e,null)},
a4L:function a4L(d,e,f,g,h){var _=this
_.c=d
_.r=e
_.w=f
_.x=g
_.a=h},
bh1:function bh1(d,e,f,g,h,i,j,k,l,m){var _=this
_.y=d
_.z=$
_.a=e
_.b=f
_.c=g
_.d=h
_.e=i
_.f=j
_.r=k
_.w=l
_.x=m},
A6:function A6(d,e,f,g){var _=this
_.a=d
_.b=e
_.c=f
_.d=g},
GQ(d,e,f,g,h,i){var x=null,w=Math.max(0,e*2-1),v=g===C.a0
v=v?H.iV:x
return new G.xB(new G.yy(new B.aE0(d,h),w,!0,!0,!0,0,new B.aE1(),x),f,g,!1,x,x,v,x,i,x,0,x,x,e,H.jp,C.z,x,x,C.x,C.cw,x)},
aE0:function aE0(d,e){this.a=d
this.b=e},
aE1:function aE1(){},
azc(d,e,f){var x=null
return new A.AR(C.a4f,!0,f,x,x,x,x,C.v,x,!1,x,!0,x,new I.X_(e,d,x,x,x),x)}},D,E,I,G,H
J=c[1]
A=c[0]
C=c[2]
F=c[102]
B=a.updateHolder(c[31],B)
D=c[114]
E=c[83]
I=c[65]
G=c[68]
H=c[91]
B.le.prototype={
bo(){var x=this
return A.Q(["id",x.a,"minimumCost",x.b,"pointsApplication",x.c,"isActive",x.d,"orderType",x.e],y.N,y.z)}}
B.jl.prototype={
bo(){var x=this
return A.Q(["id",x.a,"minimumPoints",x.b,"maximumPoints",x.c,"reward",x.d,"size",x.e,"isActive",x.f,"orderType",x.r],y.N,y.z)}}
B.a7g.prototype={
gaun(){var x=this.a
return A.fK(new A.V(x,new B.aEt(),A.F(x).i("V<1>")),y.I)},
gVq(){var x=this.b
return A.fK(new A.V(x,new B.aEv(),A.F(x).i("V<1>")),y.l)},
nD(){var x=0,w=A.m(y.H),v,u=this
var $async$nD=A.n(function(d,e){if(d===1)return A.j(e,w)
for(;;)switch(x){case 0:if(u.c){x=1
break}u.c=!0
x=3
return A.d(u.AK(),$async$nD)
case 3:case 1:return A.k(v,w)}})
return A.l($async$nD,w)},
AK(){var x=0,w=A.m(y.H),v,u=2,t=[],s=this,r,q,p,o,n,m
var $async$AK=A.n(function(d,e){if(d===1){t.push(e)
x=u}for(;;)switch(x){case 0:u=4
x=7
return A.d(A.hk(A.bH("https://curatering.up.railway.app/api/loyalty/program-config",0,null),null),$async$AK)
case 7:r=e
x=r.b===200?8:9
break
case 8:o=r
q=y.P.a(C.a7.bu(A.cI(A.cH(o.e)).bb(o.w),null))
s.aaS(q)
x=10
return A.d(s.zY(),$async$AK)
case 10:s.a4()
x=1
break
case 9:u=2
x=6
break
case 4:u=3
m=t.pop()
p=A.a9(m)
E.er().$1("Error loading loyalty program from API: "+A.h(p))
x=6
break
case 3:x=2
break
case 6:x=11
return A.d(s.OP(),$async$AK)
case 11:s.a4()
case 1:return A.k(v,w)
case 2:return A.j(t.at(-1),w)}})
return A.l($async$AK,w)},
aaS(d){var x=y.g,w=x.a(d.h(0,"pointsConditions")),v=x.a(d.h(0,"rewardsConditions"))
if(w==null)x=null
else{x=J.cg(w,new B.aEh(),y.I)
x=A.v(x,x.$ti.i("ab.E"))}this.a=x==null?A.a([],y.u):x
if(v==null)x=null
else{x=J.cg(v,new B.aEi(),y.l)
x=A.v(x,x.$ti.i("ab.E"))}this.b=x==null?A.a([],y.n):x},
OP(){var x=0,w=A.m(y.H),v,u=2,t=[],s=this,r,q,p,o,n
var $async$OP=A.n(function(d,e){if(d===1){t.push(e)
x=u}for(;;)switch(x){case 0:u=4
x=7
return A.d(A.d4(),$async$OP)
case 7:r=e
q=A.aL(r.a.h(0,"loyalty_rewards_cache_v2"))
if(q==null||q.length===0){x=1
break}s.aaS(y.P.a(C.a7.bu(q,null)))
u=2
x=6
break
case 4:u=3
n=t.pop()
p=A.a9(n)
E.er().$1("Error loading loyalty cache: "+A.h(p))
x=6
break
case 3:x=2
break
case 6:case 1:return A.k(v,w)
case 2:return A.j(t.at(-1),w)}})
return A.l($async$OP,w)},
zY(){var x=0,w=A.m(y.H),v=1,u=[],t=this,s,r,q,p,o,n,m
var $async$zY=A.n(function(d,e){if(d===1){u.push(e)
x=v}for(;;)switch(x){case 0:v=3
x=6
return A.d(A.d4(),$async$zY)
case 6:s=e
q=t.a
p=A.F(q).i("x<1,R<e,@>>")
q=A.v(new A.x(q,new B.aEj(),p),p.i("ab.E"))
p=t.b
o=A.F(p).i("x<1,R<e,@>>")
p=A.v(new A.x(p,new B.aEk(),o),o.i("ab.E"))
x=7
return A.d(s.kp("String","loyalty_rewards_cache_v2",C.a7.cr(A.Q(["pointsConditions",q,"rewardsConditions",p],y.N,y.p),null)),$async$zY)
case 7:v=1
x=5
break
case 3:v=2
m=u.pop()
r=A.a9(m)
E.er().$1("Error caching loyalty program: "+A.h(r))
x=5
break
case 2:x=1
break
case 5:return A.k(null,w)
case 1:return A.j(u.at(-1),w)}})
return A.l($async$zY,w)},
py(){var x=0,w=A.m(y.H),v,u=2,t=[],s=this,r,q,p,o,n,m,l,k,j,i,h
var $async$py=A.n(function(d,e){if(d===1){t.push(e)
x=u}for(;;)switch(x){case 0:x=3
return A.d(s.zY(),$async$py)
case 3:r=$.cA().c
if(r==null||r.length===0){x=1
break}u=5
o=A.bH("https://curatering.up.railway.app/api/manager/loyalty/program-config",0,null)
n=y.N
m=A.Q(["Authorization","Bearer "+r,"Content-Type","application/json"],n,n)
l=s.a
k=A.F(l).i("x<1,R<e,@>>")
l=A.v(new A.x(l,new B.aEl(),k),k.i("ab.E"))
k=s.b
j=A.F(k).i("x<1,R<e,@>>")
k=A.v(new A.x(k,new B.aEm(),j),j.i("ab.E"))
x=8
return A.d(A.pl(o,C.a7.cr(A.Q(["pointsConditions",l,"rewardsConditions",k],n,y.p),null),null,m),$async$py)
case 8:q=e
if(q.b>=400){o=q
E.er().$1("Failed to save loyalty program: "+A.cI(A.cH(o.e)).bb(o.w))}u=2
x=7
break
case 5:u=4
h=t.pop()
p=A.a9(h)
E.er().$1("Error saving loyalty program: "+A.h(p))
x=7
break
case 4:x=2
break
case 7:case 1:return A.k(v,w)
case 2:return A.j(t.at(-1),w)}})
return A.l($async$py,w)},
br9(d){var x=this,w=C.f.iM(x.a,new B.aEw(d))
if(w>=0){x.a[w]=d
x.py()
x.a4()}},
bdR(d){var x=this,w=C.f.iM(x.a,new B.aEn(d))
if(w>=0){x.a[w].d=!1
x.py()
x.a4()}},
bra(d){var x=this,w=C.f.iM(x.b,new B.aEx(d))
if(w>=0){x.b[w]=d
x.py()
x.a4()}},
bdS(d){var x=this,w=C.f.iM(x.b,new B.aEo(d))
if(w>=0){x.b[w].f=!1
x.py()
x.a4()}},
LB(d,e){var x,w,v,u,t,s
for(x=C.f.ga1(this.a),w=new A.jt(x,new B.aEp(e));w.A();){v=x.gS()
if(d>=v.b){u=d*v.c/100
t=C.i.aS(u,1)
s=C.i.dX(u)
return t>=0.7?s+1:s}}return 0},
atL(d){var x=this.a,w=A.F(x).i("V<1>"),v=A.v(new A.V(x,new B.aEq(d),w),w.i("r.E"))
if(v.length===0)return d==="restaurant"?100:500
return new A.x(v,new B.aEr(),A.F(v).i("x<1,S>")).i6(0,new B.aEs())},
auo(d){var x=this.a,w=A.F(x).i("V<1>"),v=A.v(new A.V(x,new B.aEu(d),w),w.i("r.E"))
if(v.length===0)return d==="restaurant"?2:8
return C.f.ga9(v).c}}
B.a4L.prototype={
D(d){var x,w,v,u,t,s,r,q,p,o=this,n=null,m=A.cbk(d),l=A.bM()
A:{x=n
if(C.bs===l||C.cN===l)break A
if(C.c9===l||C.dp===l||C.dq===l||C.dr===l){A.cm(d,C.aW,y.y).toString
x="Navigation menu"
break A}}A.a7(d)
w=d.R(y.c)
w=w==null?n:w.f
w=w==null?n:w.d
v=new B.bh1(d,n,n,1,n,n,n,n,n,C.x)
u=o.r
if(u==null)if(w!==C.nC){w=m.f
if(w==null)w=v.gc5()
u=w}else{w=m.r
if(w==null)w=v.gJ1()
u=w}w=o.w
t=o.c
if(t==null)t=m.a
if(t==null)t=v.gbO()
s=m.c
if(s==null)s=1
r=m.d
if(r==null)r=v.gbM()
q=m.e
if(q==null)q=v.gbS()
p=m.x
if(p==null)p=C.x
return A.bP(n,n,n,new A.bV(new A.ak(w,w,1/0,1/0),A.cU(!1,C.an,!0,n,o.x,p,t,s,n,r,u,q,n,C.bj),n),!1,n,n,n,n,!1,n,!0,n,n,n,n,n,n,n,n,n,n,x,n,n,n,n,n,n,!0,n,n,n,n,n,n,n,n,n,n,n,n,n,!0,n,n,n,n,n,n,n,C.ay,n)}}
B.bh1.prototype={
gmJ(){var x,w=this,v=w.z
if(v===$){x=w.y.R(y.s).w
w.z!==$&&A.b1()
w.z=x
v=x}return v},
gbO(){var x=A.a7(this.y).ax,w=x.p3
return w==null?x.k2:w},
gbS(){return C.aq},
gbM(){return C.aq},
gc5(){return new A.aw(D.a5u.a2(this.gmJ()),C.J)},
gJ1(){return new A.aw(D.a5t.a2(this.gmJ()),C.J)}}
B.A6.prototype={
gjI(){return this.a},
gmB(){return this.b},
gnc(){return this.c},
gmi(){return this.d},
gjH(){return C.ax},
gmC(){return C.ax},
gmj(){return C.ax},
gnb(){return C.ax},
aa(d,e){var x=this
return new B.A6(x.a.aa(0,e.a),x.b.aa(0,e.b),x.c.aa(0,e.c),x.d.aa(0,e.d))},
a8(d,e){var x=this
return new B.A6(x.a.a8(0,e.a),x.b.a8(0,e.b),x.c.a8(0,e.c),x.d.a8(0,e.d))},
aD(d,e){var x=this
return new B.A6(x.a.aD(0,e),x.b.aD(0,e),x.c.aD(0,e),x.d.aD(0,e))},
a2(d){var x=this
switch(d.a){case 0:return new A.df(x.b,x.a,x.d,x.c)
case 1:return new A.df(x.a,x.b,x.c,x.d)}}}
var z=a.updateTypes(["H(le)","H(jl)","R<e,@>(le)","R<e,@>(jl)","le(@)","jl(@)","S(le)"])
B.aEt.prototype={
$1(d){return d.d},
$S:z+0}
B.aEv.prototype={
$1(d){return d.f},
$S:z+1}
B.aEh.prototype={
$1(d){var x,w,v,u,t
y.P.a(d)
x=A.c3(d.h(0,"id"))
w=A.cG(d.h(0,"minimumCost"))
if(w==null)w=null
if(w==null)w=0
v=A.cG(d.h(0,"pointsApplication"))
v=v==null?null:C.i.H(v)
if(v==null)v=0
u=A.ks(d.h(0,"isActive"))
t=A.aL(d.h(0,"orderType"))
if(t==null)t="restaurant"
return new B.le(x,w,v,u!==!1,t)},
$S:z+4}
B.aEi.prototype={
$1(d){var x,w,v,u,t,s,r
y.P.a(d)
x=A.c3(d.h(0,"id"))
w=A.cG(d.h(0,"minimumPoints"))
w=w==null?null:C.i.H(w)
if(w==null)w=0
v=A.cG(d.h(0,"maximumPoints"))
v=v==null?null:C.i.H(v)
if(v==null)v=0
u=A.aL(d.h(0,"reward"))
if(u==null)u=""
t=A.aL(d.h(0,"size"))
if(t==null)t=""
s=A.ks(d.h(0,"isActive"))
r=A.aL(d.h(0,"orderType"))
if(r==null)r="restaurant"
return new B.jl(x,w,v,u,t,s!==!1,r)},
$S:z+5}
B.aEj.prototype={
$1(d){return d.bo()},
$S:z+2}
B.aEk.prototype={
$1(d){return d.bo()},
$S:z+3}
B.aEl.prototype={
$1(d){return d.bo()},
$S:z+2}
B.aEm.prototype={
$1(d){return d.bo()},
$S:z+3}
B.aEw.prototype={
$1(d){return d.a===this.a.a},
$S:z+0}
B.aEn.prototype={
$1(d){return d.a===this.a},
$S:z+0}
B.aEx.prototype={
$1(d){return d.a===this.a.a},
$S:z+1}
B.aEo.prototype={
$1(d){return d.a===this.a},
$S:z+1}
B.aEp.prototype={
$1(d){return d.d&&d.e===this.a},
$S:z+0}
B.aEq.prototype={
$1(d){return d.d&&d.e===this.a},
$S:z+0}
B.aEr.prototype={
$1(d){return d.b},
$S:z+6}
B.aEs.prototype={
$2(d,e){return d<e?d:e},
$S:61}
B.aEu.prototype={
$1(d){return d.d&&d.e===this.a},
$S:z+0}
B.aE0.prototype={
$2(d,e){var x=C.k.bA(e,2)
if((e&1)===0)return this.a.$2(d,x)
return this.b.$2(d,x)},
$S:718}
B.aE1.prototype={
$2(d,e){return(e&1)===0?C.k.bA(e,2):null},
$S:719};(function inheritance(){var x=a.inheritMany,w=a.inherit
x(A.X,[B.le,B.jl])
w(B.a7g,A.hH)
x(A.d0,[B.aEt,B.aEv,B.aEh,B.aEi,B.aEj,B.aEk,B.aEl,B.aEm,B.aEw,B.aEn,B.aEx,B.aEo,B.aEp,B.aEq,B.aEr,B.aEu])
x(A.ei,[B.aEs,B.aE0,B.aE1])
w(B.a4L,A.am)
w(B.bh1,A.G2)
w(B.A6,A.F0)})()
A.dd(b.typeUniverse,JSON.parse('{"a7g":{"aJ":[]},"a4L":{"am":[],"f":[]}}'))
var y=(function rtii(){var x=A.W
return{s:x("fT"),u:x("y<le>"),n:x("y<jl>"),p:x("a_<R<e,@>>"),P:x("R<e,@>"),y:x("kd"),I:x("le"),l:x("jl"),N:x("e"),c:x("WE"),z:x("@"),g:x("a_<@>?"),H:x("~")}})();(function constants(){D.a5t=new B.A6(F.ji,C.ax,F.ji,C.ax)
D.a5u=new B.A6(C.ax,F.ji,C.ax,F.ji)
D.IE=new A.an(61183,"MaterialIcons",!1)
D.H5=new A.ad(0,0,10,0)
D.xC=new A.ad(0,24,0,24)
D.lB=new A.ad(0,6,0,0)
D.Hb=new A.ad(12,12,12,8)
D.j5=new A.ad(16,8,16,8)
D.qE=new A.ad(18,18,18,18)
D.Hh=new A.ad(20,14,20,14)
D.p6=new A.K(!0,null,null,null,null,null,22,C.a5,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null)
D.nZ=new A.al(C.fq,null,C.w,null,null)
D.Ia=new A.an(57431,"MaterialIcons",!1)
D.mF=new A.K(!0,C.w,null,null,null,null,12,C.aa,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null)
D.a0S=new A.bo(null,18,null,null)
D.eS=new A.K(!0,null,null,null,null,null,13,C.aa,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null)
D.p7=new A.K(!0,null,null,null,null,null,11,C.aa,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null)
D.kY=new A.K(!0,null,null,null,null,null,null,C.bq,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null)
D.v9=new A.o("Close",null,null,null,null,null,null,null,null,null,null)})();(function lazyInitializers(){var x=a.lazyFinal
x($,"cHu","ku",()=>new B.a7g(A.a([],y.u),A.a([],y.n),$.a0()))})()};
(a=>{a["sO8SrAAxiiG2dMRyYRKJapJ42Pw="]=a.current})($__dart_deferred_initializers__);