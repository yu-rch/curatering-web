((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,A,B,E,C={
En(d,e,f){return C.cH9(d,e,f)},
cH9(a5,a6,a7){var x=0,w=A.l(y.H),v,u=2,t=[],s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,a0,a1,a2,a3,a4
var $async$En=A.m(function(a9,b0){if(a9===1){t.push(b0)
x=u}for(;;)switch(x){case 0:a1={}
x=!a6?3:4
break
case 3:x=5
return A.d(A.bf(null,null,!0,null,new C.c4c(a5,a7),a5,null,!0,!0,y.z),$async$En)
case 5:x=1
break
case 4:a4=A
x=6
return A.d(A.d2(),$async$En)
case 6:s=a4.aJ(b0.a.h(0,"customer_token"))
if(s==null||s.length===0){if(a5.e!=null)a5.R(y.q).f.aA(D.bs3)
x=1
break}j=a1.a=B.cy
u=8
j=y.N
x=11
return A.d(A.fH(A.bx("https://curatering.up.railway.app/api/restaurant/orders",0,null),A.N(["Authorization","Bearer "+s,"Content-Type","application/json"],j,j)).cA(B.lF),$async$En)
case 11:r=b0
if(r.b!==200){if(a5.e!=null)a5.R(y.q).f.aA(D.a1e)
x=1
break}j=r
q=B.a6.bp(A.cj(A.ci(j.e)).b7(j.w),null)
i=y.g.a(J.t(q,"orders"))
p=i==null?B.br:i
j=J.ej(p,y.f)
j=A.dg(j,new C.c4d(),j.$ti.i("q.E"),y.P)
h=A.y(j).i("S<q.E>")
g=A.v(new A.S(j,new C.c4e(),h),h.i("q.E"))
a1.a=g
j=g
u=2
x=10
break
case 8:u=7
a2=t.pop()
if(a5.e!=null)a5.R(y.q).f.aA(D.a1e)
x=1
break
x=10
break
case 7:x=2
break
case 10:if(j.length===0){if(a5.e!=null)a5.R(y.q).f.aA(D.bs2)
x=1
break}if(a5.e==null){x=1
break}a1.b=B.f.ga8(j)
a1.c=5
j=$.W()
e=new A.af(B.a3,j)
x=12
return A.d(A.bf(null,null,!0,null,new C.c4f(a1,e),a5,null,!0,!0,y.y),$async$En)
case 12:d=b0
o=B.e.l(e.a.a)
e.K$=j
e.I$=0
if(d!==!0||a5.e==null){x=1
break}j=a1.b.h(0,"id")
n=J.u(j==null?a1.b.h(0,"order_no"):j)
u=14
j=A.bx("https://curatering.up.railway.app/api/restaurant/orders/"+A.h(n)+"/feedback",0,null)
h=y.N
a0=A.N(["Authorization","Bearer "+s,"Content-Type","application/json"],h,h)
x=17
return A.d(A.et(j,B.a6.cp(A.N(["stars",a1.c,"remarks",o],h,y.K),null),null,a0),$async$En)
case 17:m=b0
if(a5.e==null){x=1
break}if(m.b===200)a5.R(y.q).f.aA(D.bs1)
else{l="Failed to submit feedback"
try{a1=m
k=B.a6.bp(A.cj(A.ci(a1.e)).b7(a1.w),null)
if(y.f.b(k)&&k.h(0,"error")!=null)l=J.u(k.h(0,"error"))}catch(a8){}a5.R(y.q).f.aA(A.cP(null,null,null,null,null,B.x,null,A.c(l,null,null,null,null,null,null,null,null),null,B.ab,null,null,null,null,null,null,null,null,null,null))}u=2
x=16
break
case 14:u=13
a3=t.pop()
if(a5.e!=null)a5.R(y.q).f.aA(D.brI)
x=16
break
case 13:x=2
break
case 16:case 1:return A.j(v,w)
case 2:return A.i(t.at(-1),w)}})
return A.k($async$En,w)},
c4c:function c4c(d,e){this.a=d
this.b=e},
c4a:function c4a(d){this.a=d},
c4b:function c4b(d,e,f){this.a=d
this.b=e
this.c=f},
c48:function c48(){},
c4d:function c4d(){},
c4e:function c4e(){},
c4f:function c4f(d,e){this.a=d
this.b=e},
c49:function c49(d,e,f){this.a=d
this.b=e
this.c=f},
c43:function c43(){},
c44:function c44(d,e){this.a=d
this.b=e},
c42:function c42(d,e){this.a=d
this.b=e},
c45:function c45(d,e){this.a=d
this.b=e},
c41:function c41(d,e,f){this.a=d
this.b=e
this.c=f},
c40:function c40(d,e){this.a=d
this.b=e},
c46:function c46(d){this.a=d},
c47:function c47(d){this.a=d},
qK:function qK(d,e,f,g,h,i){var _=this
_.c=d
_.d=e
_.e=f
_.f=g
_.r=h
_.a=i},
avx:function avx(d,e){this.a=d
this.b=e},
avn:function avn(d,e){this.a=d
this.b=e},
avm:function avm(d){this.a=d},
avo:function avo(d,e,f){this.a=d
this.b=e
this.c=f},
avp:function avp(d,e){this.a=d
this.b=e},
avq:function avq(d,e){this.a=d
this.b=e},
avr:function avr(d,e){this.a=d
this.b=e},
avs:function avs(d,e){this.a=d
this.b=e},
avt:function avt(d,e){this.a=d
this.b=e},
avu:function avu(d,e){this.a=d
this.b=e},
avl:function avl(){},
avv:function avv(d,e){this.a=d
this.b=e},
avw:function avw(d,e){this.a=d
this.b=e},
clS(d,e){var x,w
if(d!=null){x=B.e.l(J.u(d))
if(x.length!==0)return x}if(e!=null){x=B.e.l(J.u(e))
w=x.length
if(w>8)return B.e.c_(x,w-8)
if(w!==0)return x}return"N/A"}},D,F,G,H
J=c[1]
A=c[0]
B=c[2]
E=c[41]
C=a.updateHolder(c[24],C)
D=c[59]
F=c[27]
G=c[36]
H=c[47]
C.qK.prototype={
G5(d,e){var x=A.e4(e),w=y.X,v=A.kq(d,null,w),u=v==null?null:v.c.a
if((u==null?"":u)===x)return
F.rj(d,x,null,w,w)},
OO(d){return this.aYT(d)},
aYT(d){var x=0,w=A.l(y.H),v,u=2,t=[],s,r,q,p
var $async$OO=A.m(function(e,f){if(e===1){t.push(f)
x=u}for(;;)switch(x){case 0:q=B.e.l(d)
if(J.as(q)===0){x=1
break}u=4
x=7
return A.d(A.vH(A.zj(null,null,q,null,"mailto"),B.zu),$async$OO)
case 7:u=2
x=6
break
case 4:u=3
p=t.pop()
s=A.a4(p)
A.eo().$1("Failed to open mailto: "+A.h(s))
x=6
break
case 3:x=2
break
case 6:case 1:return A.j(v,w)
case 2:return A.i(t.at(-1),w)}})
return A.k($async$OO,w)},
OP(d){return this.aYU(d)},
aYU(d){var x=0,w=A.l(y.H),v=1,u=[],t=this,s,r,q,p,o,n,m,l
var $async$OP=A.m(function(e,f){if(e===1){u.push(f)
x=v}for(;;)switch(x){case 0:o=B.e.l(t.c.go)
n=o.length!==0
m=n?o:B.e.l(d)
if(B.e.b5(m,"http://")||B.e.b5(m,"https://"))q=A.bx(m,0,null)
else q=A.bx(n?o:"https://www.facebook.com/3tavs",0,null)
s=q
v=3
x=6
return A.d(A.vH(s,B.o8),$async$OP)
case 6:v=1
x=5
break
case 3:v=2
l=u.pop()
r=A.a4(l)
A.eo().$1("Failed to open Facebook: "+A.h(r))
x=5
break
case 2:x=1
break
case 5:return A.j(null,w)
case 1:return A.i(u.at(-1),w)}})
return A.k($async$OP,w)},
alh(d,e,f){var x=null,w=A.aQ(d,B.w,x,18),v=f==null,u=A.J(A.a([w,B.aj,A.F(A.c(e,1,B.aU,x,!1,A.A(x,x,B.x3,x,!v?B.eT:B.a8,B.bo,x,x,x,x,x,12,x,x,x,x,x,!0,x,x,x,x,x,x,x,x),x,x,x),1)],y.p),B.u,B.k,B.p,0,x)
return v?u:A.ct(!1,x,!0,u,x,!0,x,x,x,x,x,x,x,x,x,x,f,x,x,x,x,x,x,x)},
a1C(d,e){return this.alh(d,e,null)},
D(d){var x=null
return A.P(x,A.dO(new C.avx(this,this.c)),B.v,B.ns,x,x,x,x,x,x,D.agk,x,x,x)}}
var z=a.updateTypes(["m7(T)"])
C.c4c.prototype={
$1(d){var x=null
return A.cL(A.a([A.bt(B.bQ,x,x,x,new C.c4a(d),x,x),A.dj(D.bBj,new C.c4b(d,this.a,this.b),x)],y.p),x,x,x,D.bEc,x,x,x,D.bF4,x)},
$S:10}
C.c4a.prototype={
$0(){A.R(this.a,!1).a3(null)
return null},
$S:0}
C.c4b.prototype={
$0(){var x=0,w=A.l(y.H),v=this
var $async$$0=A.m(function(d,e){if(d===1)return A.i(e,w)
for(;;)switch(x){case 0:A.R(v.a,!1).a3(null)
x=2
return A.d(A.bf(null,null,!0,null,new C.c48(),v.b,null,!0,!0,y.z),$async$$0)
case 2:x=3
return A.d(v.c.$0(),$async$$0)
case 3:return A.j(null,w)}})
return A.k($async$$0,w)},
$S:1}
C.c48.prototype={
$1(d){return G.qw},
$S:z+0}
C.c4d.prototype={
$1(d){return A.av(d,y.N,y.z)},
$S:25}
C.c4e.prototype={
$1(d){var x,w=d.h(0,"status"),v=J.u(w==null?"":w).toLowerCase()
if(!J.n(v,"delivered"))return!1
x=d.h(0,"feedback_stars")
return x==null},
$S:17}
C.c4f.prototype={
$1(d){return new A.dU(new C.c49(this.a,this.b,d),null)},
$S:19}
C.c49.prototype={
$2(d,e){var x,w,v=null,u=this.a,t=u.b,s=A.c("Feedback \xb7 "+C.clS(t.h(0,"order_no"),t.h(0,"id")),v,v,v,v,v,v,v,v),r=y.p,q=A.a([],r),p=u.a
if(p.length>1){x=u.b
w=A.E(p).i("w<1,au<U<e,@>>>")
p=A.v(new A.w(p,new C.c43(),w),w.i("aa.E"))
B.f.t(q,A.a([A.ey(D.amR,v,v,v,!0,!1,p,v,new C.c44(u,e),v,x,y.P),B.J],r))}q.push(D.bGV)
q.push(B.D)
q.push(A.J(A.hN(5,new C.c45(u,e),!0,y.l),B.u,B.k,B.p,0,v))
q.push(B.D)
q.push(A.aE(v,B.M,!1,v,!0,B.x,v,A.aF(),this.b,v,v,v,v,v,2,D.anU,B.A,!0,v,!0,v,!1,v,B.a1,v,v,v,v,v,v,v,v,4,v,v,!1,"\u2022",v,v,v,v,v,!1,v,v,!1,v,!0,v,B.U,v,v,v,v,v,v,v,v,v,v,v,v,!0,B.L,v,B.S,v,v,v,v))
u=A.bs(A.x(q,B.E,B.k,B.a2,0,B.t),v,B.A,v,v,v,B.a0)
q=this.c
return A.cL(A.a([A.bt(B.bQ,v,v,v,new C.c46(q),v,v),A.dj(B.pg,new C.c47(q),v)],r),v,v,v,u,v,v,v,s,v)},
$S:50}
C.c43.prototype={
$1(d){var x=null
return A.e2(A.c(C.clS(d.h(0,"order_no"),d.h(0,"id")),x,x,x,x,x,x,x,x),d,y.P)},
$S:1181}
C.c44.prototype={
$1(d){if(d==null)return
this.b.$1(new C.c42(this.a,d))},
$S:1182}
C.c42.prototype={
$0(){return this.a.b=this.b},
$S:0}
C.c45.prototype={
$1(d){var x=null,w=this.a,v=d<w.c,u=v?B.jg:B.o_
return A.aO(x,x,x,A.aQ(u,v?B.mk:x,x,x),x,x,new C.c41(w,this.b,d),x,20,x,x,B.dy)},
$S:176}
C.c41.prototype={
$0(){return this.b.$1(new C.c40(this.a,this.c))},
$S:0}
C.c40.prototype={
$0(){return this.a.c=this.b+1},
$S:0}
C.c46.prototype={
$0(){A.R(this.a,!1).a3(!1)
return null},
$S:0}
C.c47.prototype={
$0(){A.R(this.a,!1).a3(!0)
return null},
$S:0}
C.avx.prototype={
$2(d,e){var x,w,v,u,t=null,s=e.b>900,r=s?t:220,q=this.b,p=y.p,o=A.a([A.bt(A.c(q.fr,t,t,t,t,D.bx4,t,t,t),t,t,t,new C.avn(d,q),t,t),A.kB(D.byN,B.L,q.y1)],p),n=this.a
if(n.d)o.push(A.hn(D.alH,D.bGm,new C.avo(n,d,q),t))
r=A.ae(A.x(o,B.E,B.k,B.p,0,B.t),t,r)
o=A.x(A.a([A.bt(A.c("Gallery",t,t,t,t,D.mL,t,t,t),t,t,t,new C.avp(n,d),t,t),A.bt(A.c("Catering Menu",t,t,t,t,D.mL,t,t,t),t,t,t,new C.avq(n,d),t,t),A.bt(A.c("Restaurant",t,t,t,t,D.mL,t,t,t),t,t,t,new C.avr(n,d),t,t)],p),B.E,B.k,B.p,0,B.t)
x=A.x(A.a([A.bt(A.c("Inquire Now",t,t,t,t,D.mL,t,t,t),t,t,t,new C.avs(n,d),t,t),A.bt(A.c("Contact Us",t,t,t,t,D.mL,t,t,t),t,t,t,new C.avt(n,d),t,t),A.bt(D.bJa,t,t,t,new C.avu(n,d),t,t)],p),B.E,B.k,B.p,0,B.t)
w=q.rx
v=A.aQ(E.yS,B.w,t,18)
w=A.ct(!1,t,!0,A.J(A.a([v,B.aj,A.F(A.c(w,1,B.aU,t,!1,A.A(t,t,B.w,t,B.eT,B.bo,t,t,t,t,t,12,t,t,t,t,t,!0,t,t,t,t,t,t,t,t),t,t,t),1)],p),B.u,B.k,B.p,0,t),t,!0,t,t,t,t,t,t,t,t,t,t,new C.avv(n,q),t,t,t,t,t,t,t)
u=A.a([r,o,x,A.ae(w,t,260),A.x(A.a([n.a1C(E.z_,q.ry),n.a1C(E.z2,q.to)],p),B.E,B.k,B.p,0,B.t),A.x(A.a([n.a1C(E.ra,q.x1),n.alh(E.yR,q.x2,new C.avw(n,q))],p),B.E,B.k,B.p,0,B.t)],p)
if(s)return A.J(A.a([new A.dH(2,B.c0,u[0],t),B.p2,u[1],B.p2,u[2],H.a10,new A.dH(3,B.c0,u[3],t),B.cV,new A.dH(3,B.c0,u[4],t),B.cV,new A.dH(2,B.c0,u[5],t),B.cV,A.n9("lib/assets/main-2.png",B.ar,!1,B.c3,B.c_,72,t)],p),B.E,B.k,B.p,0,t)
return A.ch(B.aS,u,B.aV,12,24)},
$S:1183}
C.avn.prototype={
$0(){var x=this.a,w=this.b,v=w.fr,u=w.fx
w=A.b5("\\[color=#0{3,8}\\]",!1,!1,!1)
u=A.bE(u,w,"")
w=A.b5("\\[color=#1[Ee]1[Ee]1[Ee]\\]",!1,!1,!1)
u=A.bE(u,w,"")
w=A.b5("\\[color=#262626\\]",!1,!1,!1)
u=A.bE(u,w,"")
w=A.b5("\\[color=black\\]",!1,!1,!1)
u=A.bE(u,w,"")
u=A.bE(u,"[/color]","")
w=A.b5("color\\s*:\\s*#0{3,8}\\s*;?",!1,!1,!1)
u=A.bE(u,w,"")
w=A.b5("color\\s*:\\s*black\\s*;?",!1,!1,!1)
w=A.kB(D.buV,B.L,A.bE(u,w,""))
A.eu(A.a([new A.dz("Close",null,new C.avm(x),!1,null)],y.p),!0,w,x,560,!0,v,y.H)},
$S:0}
C.avm.prototype={
$0(){A.R(this.a,!1).a3(null)
return null},
$S:0}
C.avo.prototype={
$0(){var x=0,w=A.l(y.H),v,u=this,t,s
var $async$$0=A.m(function(d,e){if(d===1)return A.i(e,w)
for(;;)switch(x){case 0:t=u.c
x=3
return A.d(A.th(u.b,t.y1,"Edit footer copyright"),$async$$0)
case 3:s=e
if(s==null||s.length===0){x=1
break}t.y1=s
x=4
return A.d(t.hD(),$async$$0)
case 4:t=u.a.r
if(t!=null)t.$0()
case 1:return A.j(v,w)}})
return A.k($async$$0,w)},
$S:1}
C.avp.prototype={
$0(){return this.a.G5(this.b,"/gallery")},
$S:0}
C.avq.prototype={
$0(){return this.a.G5(this.b,"/catering-menu")},
$S:0}
C.avr.prototype={
$0(){return this.a.G5(this.b,"/restaurant")},
$S:0}
C.avs.prototype={
$0(){return this.a.G5(this.b,"/inquire")},
$S:0}
C.avt.prototype={
$0(){return this.a.G5(this.b,"/contact-us")},
$S:0}
C.avu.prototype={
$0(){var x=this.a,w=x.f
if(w==null)w=new C.avl()
return C.En(this.b,x.e,w)},
$S:0}
C.avl.prototype={
$0(){var x=0,w=A.l(y.H)
var $async$$0=A.m(function(d,e){if(d===1)return A.i(e,w)
for(;;)switch(x){case 0:return A.j(null,w)}})
return A.k($async$$0,w)},
$S:1}
C.avv.prototype={
$0(){return this.a.OP(this.b.rx)},
$S:0}
C.avw.prototype={
$0(){return this.a.OO(this.b.x2)},
$S:0};(function inheritance(){var x=a.inheritMany,w=a.inherit
x(A.ht,[C.c4c,C.c48,C.c4d,C.c4e,C.c4f,C.c43,C.c44,C.c45])
x(A.jF,[C.c4a,C.c4b,C.c42,C.c41,C.c40,C.c46,C.c47,C.avn,C.avm,C.avo,C.avp,C.avq,C.avr,C.avs,C.avt,C.avu,C.avl,C.avv,C.avw])
x(A.kM,[C.c49,C.avx])
w(C.qK,A.ap)})()
A.kF(b.typeUniverse,JSON.parse('{"qK":{"ap":[],"f":[]}}'))
var y=(function rtii(){var x=A.ak
return{p:x("G<f>"),P:x("U<e,@>"),f:x("U<@,@>"),K:x("a8"),N:x("e"),l:x("f"),q:x("t9"),y:x("O"),z:x("@"),g:x("Y<@>?"),X:x("a8?"),H:x("~")}})();(function constants(){D.agk=new A.ac(40,20,40,20)
D.alH=new A.aj(B.hQ,14,B.bo,null,null)
D.amR=new A.aW(null,null,null,"Order",null,null,null,null,null,null,null,null,null,null,null,null,!0,!0,!1,null,null,null,null,null,null,!0,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,!0,null,null,null,null)
D.anU=new A.aW(null,null,null,"Remarks",null,null,null,null,null,null,"Optional comments about your completed order",null,null,null,null,null,!0,!0,!1,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,!0,null,null,null,null)
D.bBP=new A.o("Failed to submit feedback",null,null,null,null,null,null,null,null,null,null)
D.brI=new A.c4(D.bBP,null,null,null,null,null,null,null,null,null,null,null,null,B.ab,!1,null,null,null,B.x,null)
D.bH8=new A.o("Thank you for your feedback",null,null,null,null,null,null,null,null,null,null)
D.bs1=new A.c4(D.bH8,null,null,null,null,null,null,null,null,null,null,null,null,B.ab,!1,null,null,null,B.x,null)
D.bEj=new A.o("No delivered restaurant orders available for feedback",null,null,null,null,null,null,null,null,null,null)
D.bs2=new A.c4(D.bEj,null,null,null,null,null,null,null,null,null,null,null,null,B.ab,!1,null,null,null,B.x,null)
D.bHd=new A.o("Please log in to submit feedback",null,null,null,null,null,null,null,null,null,null)
D.bs3=new A.c4(D.bHd,null,null,null,null,null,null,null,null,null,null,null,null,B.ab,!1,null,null,null,B.x,null)
D.bIj=new A.o("Could not load your orders",null,null,null,null,null,null,null,null,null,null)
D.a1e=new A.c4(D.bIj,null,null,null,null,null,null,null,null,null,null,null,null,B.ab,!1,null,null,null,B.x,null)
D.abw=new A.Q(1,0.12156862745098039,0.1607843137254902,0.21568627450980393,B.F)
D.buV=new A.M(!0,D.abw,null,null,null,null,14,null,null,null,null,null,1.55,null,null,null,null,null,null,null,null,null,null,null,null,null)
D.bx4=new A.M(!0,B.T,null,null,null,null,null,B.a9,null,null,null,null,null,null,null,null,null,B.eT,B.T,null,null,null,null,null,null,null)
D.aaG=new A.Q(1,0.9098039215686274,0.9176470588235294,0.9294117647058824,B.F)
D.byN=new A.M(!0,D.aaG,null,null,null,null,11,null,null,null,null,null,1.4,null,null,null,null,null,null,null,null,null,null,null,null,null)
D.mL=new A.M(!0,B.x3,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null)
D.bBj=new A.o("Log in",null,null,null,null,null,null,null,null,null,null)
D.bEc=new A.o("Please log in to share feedback on a completed order.",null,null,null,null,null,null,null,null,null,null)
D.bF4=new A.o("Feedback",null,null,null,null,null,null,null,null,null,null)
D.btT=new A.M(!0,B.bo,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null)
D.bGm=new A.o("Edit",null,D.btT,null,null,null,null,null,null,null,null)
D.bGV=new A.o("How was this restaurant order?",null,null,null,null,null,null,null,null,null,null)
D.bJa=new A.o("Feedback",null,D.mL,null,null,null,null,null,null,null,null)})()};
(a=>{a["eLT6OP0ud+bDU49pvrrwBCat43s="]=a.current})($__dart_deferred_initializers__);