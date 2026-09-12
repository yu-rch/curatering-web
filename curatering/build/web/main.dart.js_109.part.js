((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,B,C,A={
cih(d,e,f){var x,w,v,u,t
if(f<=C.f.ga9(e))return C.f.ga9(d)
if(f>=C.f.gaU(e))return C.f.gaU(d)
x=C.f.blK(e,new A.c_I(f))
w=d[x]
v=x+1
u=d[v]
t=e[x]
t=B.ag(w,u,(f-t)/(e[v]-t))
t.toString
return t},
cB9(d,e,f,g,h){var x,w,v=F.abA(null,null,y.b)
v.t(0,e)
v.t(0,g)
x=B.v(v,v.$ti.c)
x.$flags=1
w=x
x=B.F(w).i("x<1,P>")
x=B.v(new B.x(w,new A.c_8(d,e,f,g,h),x),x.i("ab.E"))
x.$flags=1
return new A.b3G(x,w)},
ccQ(d,e,f){var x,w,v,u,t
if(d==e)return d
if(d==null)return e.bi(f)
if(e==null)return d.bi(1-f)
x=A.cB9(d.a,d.a_D(),e.a,e.a_D(),f)
w=B.zV(d.d,e.d,f)
w.toString
v=B.zV(d.e,e.e,f)
v.toString
u=f<0.5
t=u?d.f:e.f
u=u?d.c:e.c
return new A.ld(w,v,t,x.a,x.b,u)},
b3G:function b3G(d,e){this.a=d
this.b=e},
c_I:function c_I(d){this.a=d},
c_8:function c_8(d,e,f,g,h){var _=this
_.a=d
_.b=e
_.c=f
_.d=g
_.e=h},
aB7:function aB7(){},
ld:function ld(d,e,f,g,h,i){var _=this
_.d=d
_.e=e
_.f=f
_.a=g
_.b=h
_.c=i},
aDV:function aDV(d){this.a=d},
abi:function abi(d,e,f,g){var _=this
_.a=d
_.b=e
_.c=f
_.d=g},
abj:function abj(){},
TD:function TD(d,e,f,g,h,i){var _=this
_.a=d
_.b=e
_.c=f
_.d=g
_.e=h
_.f=i},
TC:function TC(){},
Ir:function Ir(d,e,f){var _=this
_.b=_.w=null
_.c=!1
_.CL$=d
_.dQ$=e
_.aQ$=f
_.a=null},
a9Z:function a9Z(d,e,f,g,h,i,j){var _=this
_.L=d
_.y1=e
_.y2=f
_.cS$=g
_.aq$=h
_.d9$=i
_.b=_.dy=null
_.c=0
_.y=_.d=null
_.z=!0
_.Q=null
_.as=!1
_.at=null
_.ay=$
_.ch=j
_.CW=!1
_.cx=$
_.cy=!0
_.db=!1
_.dx=$},
AJ:function AJ(d,e,f){this.c=d
this.d=e
this.a=f},
np(d,e,f,g,h,i,j,k,l){var x,w=null
if(k==null){x=d==null
x=x?E.iV:w}else x=k
return new A.rB(f,new D.yy(g,h,!0,!0,!0,0,D.aq8(),w),j,C.a0,!1,d,w,x,w,l,w,0,w,w,h,E.jp,e,w,w,C.x,C.cw,i)},
rB:function rB(d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,a0){var _=this
_.to=d
_.x1=e
_.dx=f
_.c=g
_.d=h
_.e=i
_.f=j
_.r=k
_.w=l
_.x=m
_.y=n
_.z=o
_.Q=p
_.as=q
_.at=r
_.ax=s
_.ay=t
_.ch=u
_.CW=v
_.cx=w
_.cy=x
_.a=a0},
abh:function abh(d,e,f){this.f=d
this.d=e
this.a=f},
fz(d,e,f,g){return C.hl.aqn(d,null,"Poppins",G.A4,e,null,f,null,g)}},F,G,D,E
J=c[1]
B=c[0]
C=c[2]
A=a.updateHolder(c[64],A)
F=c[79]
G=c[110]
D=c[68]
E=c[91]
A.b3G.prototype={}
A.aB7.prototype={
a_D(){var x,w,v,u=this.b
if(u!=null)return u
u=this.a.length
x=1/(u-1)
w=J.kb(u,y.b)
for(v=0;v<u;++v)w[v]=v*x
return w}}
A.ld.prototype={
a3C(d,e){var x=this,w=x.d.a2(e).avX(d),v=x.e.a2(e).avX(d),u=x.a_D()
return B.c4G(w,v,x.a,u,x.f,null)},
aqu(d){return this.a3C(d,null)},
bi(d){var x=this,w=x.a,v=B.F(w).i("x<1,P>")
w=B.v(new B.x(w,new A.aDV(d),v),v.i("ab.E"))
return new A.ld(x.d,x.e,x.f,w,x.b,x.c)},
fn(d,e){var x=A.ccQ(d,this,e)
return x},
fo(d,e){var x=A.ccQ(this,d,e)
return x},
m(d,e){var x=this
if(e==null)return!1
if(x===e)return!0
if(J.ay(e)!==B.a8(x))return!1
return e instanceof A.ld&&e.d.m(0,x.d)&&e.e.m(0,x.e)&&e.f===x.f&&B.ew(e.a,x.a)&&B.ew(e.b,x.b)},
gC(d){var x=this,w=B.aR(x.a),v=x.b
v=v==null?null:B.aR(v)
return B.ap(x.d,x.e,x.f,x.c,w,v,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c,C.c)},
j(d){var x=this,w=B.a(["begin: "+x.d.j(0),"end: "+x.e.j(0),"colors: "+B.h(x.a)],y.x),v=x.b
if(v!=null)w.push("stops: "+B.h(v))
w.push("tileMode: "+x.f.j(0))
return"LinearGradient("+C.f.b_(w,", ")+")"}}
A.abi.prototype={
awC(d){var x=this.c
return d.Id(this.d,x,x)},
j(d){var x=this
return"SliverGridGeometry("+C.f.b_(B.a(["scrollOffset: "+B.h(x.a),"crossAxisOffset: "+B.h(x.b),"mainAxisExtent: "+B.h(x.c),"crossAxisExtent: "+B.h(x.d)],y.x),", ")+")"}}
A.abj.prototype={}
A.TD.prototype={
a80(d){var x=this.b
return x>1e-10?this.a*C.i.eo(d,x):0},
a7Z(d){var x=this.b
if(x>0)return Math.max(0,this.a*C.i.e5(d/x)-1)
return 0},
aQU(d){var x,w,v=this
if(v.f){x=v.c
w=v.e
return v.a*x-d-w-(x-w)}return d},
Lw(d){var x=this,w=x.a,v=C.k.aS(d,w)
return new A.abi(C.k.eo(d,w)*x.b,x.aQU(v*x.c),x.d,x.e)},
a3f(d){var x
if(d===0)return 0
x=this.b
return x*(C.k.eo(d-1,this.a)+1)-(x-this.d)}}
A.TC.prototype={}
A.Ir.prototype={
j(d){return"crossAxisOffset="+B.h(this.w)+"; "+this.aBq(0)}}
A.a9Z.prototype={
h7(d){if(!(d.b instanceof A.Ir))d.b=new A.Ir(!1,null,null)},
saxt(d){var x=this
if(x.L===d)return
if(B.a8(d)!==B.a8(x.L)||d.ls(x.L))x.ah()
x.L=d},
C5(d){var x=d.b
x.toString
x=y.t.a(x).w
x.toString
return x},
c3(){var x,w,v,u,t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,a0,a1,a2,a3,a4,a5,a6=this,a7=null,a8=y.z.a(B.a5.prototype.gal.call(a6)),a9=a6.y1
a9.R8=!1
x=a8.d
w=x+a8.z
v=w+a8.Q
u=a6.L.E9(a8)
t=u.a80(w)
s=isFinite(v)?u.a7Z(v):a7
if(a6.aq$!=null){r=a6.apo(t)
a6.xC(r,s!=null?a6.app(s):0)}else a6.xC(0,0)
q=u.Lw(t)
if(a6.aq$==null)if(!a6.a2t(t,q.a)){p=u.a3f(a9.gC4())
a6.dy=D.mI(a7,!1,a7,a7,p,0,0,p,a7)
a9.xT()
return}o=q.a
n=o+q.c
m=a6.aq$
m.toString
m=m.b
m.toString
l=y.c
m=l.a(m).b
m.toString
k=m-1
m=y.t
j=a7
for(;k>=t;--k){i=u.Lw(k)
h=i.c
g=a6.asM(a8.Id(i.d,h,h))
f=g.b
f.toString
m.a(f)
e=i.a
f.a=e
f.w=i.b
if(j==null)j=g
n=Math.max(n,e+h)}if(j==null){h=a6.aq$
h.toString
h.i4(q.awC(a8))
j=a6.aq$
h=j.b
h.toString
m.a(h)
h.a=o
h.w=q.b}h=j.b
h.toString
h=l.a(h).b
h.toString
k=h+1
h=B.A(a6).i("aU.1")
f=s!=null
for(;;){if(!(!f||k<=s)){d=!1
break}i=u.Lw(k)
e=i.c
a0=a8.Id(i.d,e,e)
a1=j.b
a1.toString
g=h.a(a1).aQ$
if(g!=null){a1=g.b
a1.toString
a1=l.a(a1).b
a1.toString
a1=a1!==k}else a1=!0
if(a1){g=a6.asK(a0,j)
if(g==null){d=!0
break}}else g.i4(a0)
a1=g.b
a1.toString
m.a(a1)
a2=i.a
a1.a=a2
a1.w=i.b
n=Math.max(n,a2+e);++k
j=g}m=a6.d9$
m.toString
m=m.b
m.toString
m=l.a(m).b
m.toString
a3=d?n:a9.a4k(a8,t,m,o,n)
a4=a6.xA(a8,Math.min(x,o),n)
a5=a6.C1(a8,o,n)
a6.dy=D.mI(a5,a3>a4||x>0||a8.f!==0,a7,a7,a3,a4,0,a3,a7)
if(a3===n)a9.R8=!0
a9.xT()}}
A.AJ.prototype={
D(d){var x=null
return B.pO(!1,!1,this.d,x,!this.c,x,x,!1,x,x,x,x,x,!0)}}
A.rB.prototype={
ap7(d){return new A.abh(this.to,this.x1,null)}}
A.abh.prototype={
bg(d){var x=new A.a9Z(this.f,y.v.a(d),B.I(y.e,y.g),0,null,null,B.aY())
x.bf()
return x},
bm(d,e){e.saxt(this.f)},
a4j(d,e,f,g,h){var x
this.aBr(d,e,f,g,h)
x=this.f.E9(d).a3f(this.d.gCB())
return x}}
var z=a.updateTypes([])
A.c_I.prototype={
$1(d){return d<=this.a},
$S:323}
A.c_8.prototype={
$1(d){var x=this,w=B.ag(A.cih(x.a,x.b,d),A.cih(x.c,x.d,d),x.e)
w.toString
return w},
$S:786}
A.aDV.prototype={
$1(d){var x=B.ag(null,d,this.a)
x.toString
return x},
$S:129};(function inheritance(){var x=a.inheritMany,w=a.inherit
x(B.X,[A.b3G,A.aB7,A.abi,A.abj,A.TC])
x(B.d0,[A.c_I,A.c_8,A.aDV])
w(A.ld,A.aB7)
w(A.TD,A.abj)
w(A.Ir,D.jp)
w(A.a9Z,D.tb)
w(A.AJ,B.am)
w(A.rB,D.MV)
w(A.abh,D.qq)})()
B.dd(b.typeUniverse,JSON.parse('{"Ir":{"jp":[],"vr":[],"hJ":["Z"],"pZ":[],"eI":[]},"a9Z":{"tb":[],"eJ":[],"aU":["Z","jp"],"a5":[],"b9":[],"aU.1":"jp","aU.0":"Z"},"AJ":{"am":[],"f":[]},"rB":{"am":[],"f":[]},"abh":{"qq":[],"b2":[],"f":[]}}'))
var y={x:B.W("y<e>"),g:B.W("Z"),z:B.W("nO"),t:B.W("Ir"),v:B.W("yz"),c:B.W("jp"),b:B.W("S"),e:B.W("u")}};
(a=>{a["di5Wt0ZOKfOK3mh1AKH7lzg9JJw="]=a.current})($__dart_deferred_initializers__);