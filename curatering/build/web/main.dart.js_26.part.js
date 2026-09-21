((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,A,B,E,C={
En(d,e,f){return C.cH0(d,e,f)},
cH0(a5,a6,a7){var x=0,w=A.l(y.H),v,u=2,t=[],s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,a0,a1,a2,a3,a4
var $async$En=A.m(function(a9,b0){if(a9===1){t.push(b0)
x=u}for(;;)switch(x){case 0:a1={}
x=!a6?3:4
break
case 3:x=5
return A.d(A.bf(null,null,!0,null,new C.c41(a5,a7),a5,null,!0,!0,y.z),$async$En)
case 5:x=1
break
case 4:a4=A
x=6
return A.d(A.d2(),$async$En)
case 6:s=a4.aK(b0.a.h(0,"customer_token"))
if(s==null||s.length===0){if(a5.e!=null)a5.R(y.q).f.aA(D.bs0)
x=1
break}j=a1.a=B.cA
u=8
j=y.N
x=11
return A.d(A.fI(A.bx("https://curatering.up.railway.app/api/restaurant/orders",0,null),A.N(["Authorization","Bearer "+s,"Content-Type","application/json"],j,j)).cA(B.lE),$async$En)
case 11:r=b0
if(r.b!==200){if(a5.e!=null)a5.R(y.q).f.aA(D.a18)
x=1
break}j=r
q=B.a6.bp(A.cj(A.ci(j.e)).b7(j.w),null)
i=y.g.a(J.t(q,"orders"))
p=i==null?B.br:i
j=J.ej(p,y.f)
j=A.dh(j,new C.c42(),j.$ti.i("q.E"),y.P)
h=A.y(j).i("T<q.E>")
g=A.v(new A.T(j,new C.c43(),h),h.i("q.E"))
a1.a=g
j=g
u=2
x=10
break
case 8:u=7
a2=t.pop()
if(a5.e!=null)a5.R(y.q).f.aA(D.a18)
x=1
break
x=10
break
case 7:x=2
break
case 10:if(j.length===0){if(a5.e!=null)a5.R(y.q).f.aA(D.bs_)
x=1
break}if(a5.e==null){x=1
break}a1.b=B.f.ga8(j)
a1.c=5
j=$.W()
e=new A.af(B.a3,j)
x=12
return A.d(A.bf(null,null,!0,null,new C.c44(a1,e),a5,null,!0,!0,y.y),$async$En)
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
break}if(m.b===200)a5.R(y.q).f.aA(D.brZ)
else{l="Failed to submit feedback"
try{a1=m
k=B.a6.bp(A.cj(A.ci(a1.e)).b7(a1.w),null)
if(y.f.b(k)&&k.h(0,"error")!=null)l=J.u(k.h(0,"error"))}catch(a8){}a5.R(y.q).f.aA(A.cR(null,null,null,null,null,B.w,null,A.c(l,null,null,null,null,null,null,null,null),null,B.ab,null,null,null,null,null,null,null,null,null,null))}u=2
x=16
break
case 14:u=13
a3=t.pop()
if(a5.e!=null)a5.R(y.q).f.aA(D.brF)
x=16
break
case 13:x=2
break
case 16:case 1:return A.j(v,w)
case 2:return A.i(t.at(-1),w)}})
return A.k($async$En,w)},
c41:function c41(d,e){this.a=d
this.b=e},
c4_:function c4_(d){this.a=d},
c40:function c40(d,e,f){this.a=d
this.b=e
this.c=f},
c3Y:function c3Y(){},
c42:function c42(){},
c43:function c43(){},
c44:function c44(d,e){this.a=d
this.b=e},
c3Z:function c3Z(d,e,f){this.a=d
this.b=e
this.c=f},
c3T:function c3T(){},
c3U:function c3U(d,e){this.a=d
this.b=e},
c3S:function c3S(d,e){this.a=d
this.b=e},
c3V:function c3V(d,e){this.a=d
this.b=e},
c3R:function c3R(d,e,f){this.a=d
this.b=e
this.c=f},
c3Q:function c3Q(d,e){this.a=d
this.b=e},
c3W:function c3W(d){this.a=d},
c3X:function c3X(d){this.a=d},
qJ:function qJ(d,e,f,g,h,i){var _=this
_.c=d
_.d=e
_.e=f
_.f=g
_.r=h
_.a=i},
avt:function avt(d,e){this.a=d
this.b=e},
avj:function avj(d,e){this.a=d
this.b=e},
avi:function avi(d){this.a=d},
avk:function avk(d,e,f){this.a=d
this.b=e
this.c=f},
avl:function avl(d,e){this.a=d
this.b=e},
avm:function avm(d,e){this.a=d
this.b=e},
avn:function avn(d,e){this.a=d
this.b=e},
avo:function avo(d,e){this.a=d
this.b=e},
avp:function avp(d,e){this.a=d
this.b=e},
avq:function avq(d,e){this.a=d
this.b=e},
avh:function avh(){},
avr:function avr(d,e){this.a=d
this.b=e},
avs:function avs(d,e){this.a=d
this.b=e},
clK(d,e){var x,w
if(d!=null){x=B.e.l(J.u(d))
if(x.length!==0)return x}if(e!=null){x=B.e.l(J.u(e))
w=x.length
if(w>8)return B.e.c_(x,w-8)
if(w!==0)return x}return"N/A"}},D,F,G,H
J=c[1]
A=c[0]
B=c[2]
E=c[42]
C=a.updateHolder(c[25],C)
D=c[61]
F=c[28]
G=c[37]
H=c[49]
C.qJ.prototype={
G5(d,e){var x=A.e5(e),w=y.X,v=A.ks(d,null,w),u=v==null?null:v.c.a
if((u==null?"":u)===x)return
F.ri(d,x,null,w,w)},
OO(d){return this.aYT(d)},
aYT(d){var x=0,w=A.l(y.H),v,u=2,t=[],s,r,q,p
var $async$OO=A.m(function(e,f){if(e===1){t.push(f)
x=u}for(;;)switch(x){case 0:q=B.e.l(d)
if(J.as(q)===0){x=1
break}u=4
x=7
return A.d(A.vF(A.zi(null,null,q,null,"mailto"),B.zo),$async$OO)
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
return A.d(A.vF(s,B.oa),$async$OP)
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
alg(d,e,f){var x=null,w=A.aR(d,B.x,x,18),v=f==null,u=A.K(A.a([w,B.aj,A.F(A.c(e,1,B.aU,x,!1,A.A(x,x,B.x_,x,!v?B.eS:B.a8,B.bp,x,x,x,x,x,12,x,x,x,x,x,!0,x,x,x,x,x,x,x,x),x,x,x),1)],y.p),B.u,B.k,B.p,0,x)
return v?u:A.cx(!1,x,!0,u,x,!0,x,x,x,x,x,x,x,x,x,x,f,x,x,x,x,x,x,x)},
a1A(d,e){return this.alg(d,e,null)},
D(d){var x=null
return A.Q(x,A.dN(new C.avt(this,this.c)),B.v,B.nr,x,x,x,x,x,x,D.agk,x,x,x)}}
var z=a.updateTypes(["m5(S)"])
C.c41.prototype={
$1(d){var x=null
return A.cL(A.a([A.bt(B.bQ,x,x,x,new C.c4_(d),x,x),A.dg(D.bBh,new C.c40(d,this.a,this.b),x)],y.p),x,x,x,D.bE9,x,x,x,D.bF0,x)},
$S:10}
C.c4_.prototype={
$0(){A.R(this.a,!1).a2(null)
return null},
$S:0}
C.c40.prototype={
$0(){var x=0,w=A.l(y.H),v=this
var $async$$0=A.m(function(d,e){if(d===1)return A.i(e,w)
for(;;)switch(x){case 0:A.R(v.a,!1).a2(null)
x=2
return A.d(A.bf(null,null,!0,null,new C.c3Y(),v.b,null,!0,!0,y.z),$async$$0)
case 2:x=3
return A.d(v.c.$0(),$async$$0)
case 3:return A.j(null,w)}})
return A.k($async$$0,w)},
$S:1}
C.c3Y.prototype={
$1(d){return G.qw},
$S:z+0}
C.c42.prototype={
$1(d){return A.av(d,y.N,y.z)},
$S:24}
C.c43.prototype={
$1(d){var x,w=d.h(0,"status"),v=J.u(w==null?"":w).toLowerCase()
if(!J.n(v,"delivered"))return!1
x=d.h(0,"feedback_stars")
return x==null},
$S:17}
C.c44.prototype={
$1(d){return new A.dU(new C.c3Z(this.a,this.b,d),null)},
$S:19}
C.c3Z.prototype={
$2(d,e){var x,w,v=null,u=this.a,t=u.b,s=A.c("Feedback \xb7 "+C.clK(t.h(0,"order_no"),t.h(0,"id")),v,v,v,v,v,v,v,v),r=y.p,q=A.a([],r),p=u.a
if(p.length>1){x=u.b
w=A.E(p).i("w<1,au<U<e,@>>>")
p=A.v(new A.w(p,new C.c3T(),w),w.i("aa.E"))
B.f.t(q,A.a([A.ey(D.amQ,v,v,v,!0,!1,p,v,new C.c3U(u,e),v,x,y.P),B.J],r))}q.push(D.bGR)
q.push(B.D)
q.push(A.K(A.hM(5,new C.c3V(u,e),!0,y.l),B.u,B.k,B.p,0,v))
q.push(B.D)
q.push(A.aE(v,B.N,!1,v,!0,B.w,v,A.aF(),this.b,v,v,v,v,v,2,D.anT,B.A,!0,v,!0,v,!1,v,B.a1,v,v,v,v,v,v,v,v,4,v,v,!1,"\u2022",v,v,v,v,v,!1,v,v,!1,v,!0,v,B.U,v,v,v,v,v,v,v,v,v,v,v,v,!0,B.L,v,B.S,v,v,v,v))
u=A.bs(A.x(q,B.E,B.k,B.a2,0,B.t),v,B.A,v,v,v,B.a0)
q=this.c
return A.cL(A.a([A.bt(B.bQ,v,v,v,new C.c3W(q),v,v),A.dg(B.pg,new C.c3X(q),v)],r),v,v,v,u,v,v,v,s,v)},
$S:48}
C.c3T.prototype={
$1(d){var x=null
return A.e3(A.c(C.clK(d.h(0,"order_no"),d.h(0,"id")),x,x,x,x,x,x,x,x),d,y.P)},
$S:1180}
C.c3U.prototype={
$1(d){if(d==null)return
this.b.$1(new C.c3S(this.a,d))},
$S:1181}
C.c3S.prototype={
$0(){return this.a.b=this.b},
$S:0}
C.c3V.prototype={
$1(d){var x=null,w=this.a,v=d<w.c,u=v?B.je:B.nZ
return A.aQ(x,x,x,A.aR(u,v?B.mj:x,x,x),x,x,new C.c3R(w,this.b,d),x,20,x,x,B.dO)},
$S:176}
C.c3R.prototype={
$0(){return this.b.$1(new C.c3Q(this.a,this.c))},
$S:0}
C.c3Q.prototype={
$0(){return this.a.c=this.b+1},
$S:0}
C.c3W.prototype={
$0(){A.R(this.a,!1).a2(!1)
return null},
$S:0}
C.c3X.prototype={
$0(){A.R(this.a,!1).a2(!0)
return null},
$S:0}
C.avt.prototype={
$2(d,e){var x,w,v,u,t=null,s=e.b>900,r=s?t:220,q=this.b,p=y.p,o=A.a([A.bt(A.c(q.fr,t,t,t,t,D.bx1,t,t,t),t,t,t,new C.avj(d,q),t,t),new A.im(q.y1,D.byK,B.L,1,B.aU,t)],p),n=this.a
if(n.d)o.push(A.hm(D.alG,D.bGh,new C.avk(n,d,q),t))
r=A.ae(A.x(o,B.E,B.k,B.p,0,B.t),t,r)
o=A.x(A.a([A.bt(A.c("Gallery",t,t,t,t,D.mJ,t,t,t),t,t,t,new C.avl(n,d),t,t),A.bt(A.c("Catering Menu",t,t,t,t,D.mJ,t,t,t),t,t,t,new C.avm(n,d),t,t),A.bt(A.c("Restaurant",t,t,t,t,D.mJ,t,t,t),t,t,t,new C.avn(n,d),t,t)],p),B.E,B.k,B.p,0,B.t)
x=A.x(A.a([A.bt(A.c("Inquire Now",t,t,t,t,D.mJ,t,t,t),t,t,t,new C.avo(n,d),t,t),A.bt(A.c("Contact Us",t,t,t,t,D.mJ,t,t,t),t,t,t,new C.avp(n,d),t,t),A.bt(D.bJ6,t,t,t,new C.avq(n,d),t,t)],p),B.E,B.k,B.p,0,B.t)
w=q.rx
v=A.aR(E.yN,B.x,t,18)
w=A.cx(!1,t,!0,A.K(A.a([v,B.aj,A.F(A.c(w,1,B.aU,t,!1,A.A(t,t,B.x,t,B.eS,B.bp,t,t,t,t,t,12,t,t,t,t,t,!0,t,t,t,t,t,t,t,t),t,t,t),1)],p),B.u,B.k,B.p,0,t),t,!0,t,t,t,t,t,t,t,t,t,t,new C.avr(n,q),t,t,t,t,t,t,t)
u=A.a([r,o,x,A.ae(w,t,260),A.x(A.a([n.a1A(E.yV,q.ry),n.a1A(E.yY,q.to)],p),B.E,B.k,B.p,0,B.t),A.x(A.a([n.a1A(E.r9,q.x1),n.alg(E.yM,q.x2,new C.avs(n,q))],p),B.E,B.k,B.p,0,B.t)],p)
if(s)return A.K(A.a([new A.dL(2,B.c3,u[0],t),B.p3,u[1],B.p3,u[2],H.a0V,new A.dL(3,B.c3,u[3],t),B.cW,new A.dL(3,B.c3,u[4],t),B.cW,new A.dL(2,B.c3,u[5],t),B.cW,A.na("lib/assets/main-2.png",B.ar,!1,B.c2,B.c_,72,t)],p),B.E,B.k,B.p,0,t)
return A.cg(B.aP,u,B.aV,12,24)},
$S:1182}
C.avj.prototype={
$0(){var x=null,w=this.a,v=this.b,u=v.fr,t=v.fx
v=A.b5("\\[color=#0{3,8}\\]",!1,!1,!1)
t=A.bE(t,v,"")
v=A.b5("\\[color=#1[Ee]1[Ee]1[Ee]\\]",!1,!1,!1)
t=A.bE(t,v,"")
v=A.b5("\\[color=#262626\\]",!1,!1,!1)
t=A.bE(t,v,"")
v=A.b5("\\[color=black\\]",!1,!1,!1)
t=A.bE(t,v,"")
t=A.bE(t,"[/color]","")
v=A.b5("color\\s*:\\s*#0{3,8}\\s*;?",!1,!1,!1)
t=A.bE(t,v,"")
v=A.b5("color\\s*:\\s*black\\s*;?",!1,!1,!1)
t=A.bE(t,v,"")
A.eu(A.a([new A.dz("Close",x,new C.avi(w),!1,x)],y.p),!0,new A.im(t,D.buS,B.L,x,B.cg,x),w,560,!0,u,y.H)},
$S:0}
C.avi.prototype={
$0(){A.R(this.a,!1).a2(null)
return null},
$S:0}
C.avk.prototype={
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
C.avl.prototype={
$0(){return this.a.G5(this.b,"/gallery")},
$S:0}
C.avm.prototype={
$0(){return this.a.G5(this.b,"/catering-menu")},
$S:0}
C.avn.prototype={
$0(){return this.a.G5(this.b,"/restaurant")},
$S:0}
C.avo.prototype={
$0(){return this.a.G5(this.b,"/inquire")},
$S:0}
C.avp.prototype={
$0(){return this.a.G5(this.b,"/contact-us")},
$S:0}
C.avq.prototype={
$0(){var x=this.a,w=x.f
if(w==null)w=new C.avh()
return C.En(this.b,x.e,w)},
$S:0}
C.avh.prototype={
$0(){var x=0,w=A.l(y.H)
var $async$$0=A.m(function(d,e){if(d===1)return A.i(e,w)
for(;;)switch(x){case 0:return A.j(null,w)}})
return A.k($async$$0,w)},
$S:1}
C.avr.prototype={
$0(){return this.a.OP(this.b.rx)},
$S:0}
C.avs.prototype={
$0(){return this.a.OO(this.b.x2)},
$S:0};(function inheritance(){var x=a.inheritMany,w=a.inherit
x(A.ht,[C.c41,C.c3Y,C.c42,C.c43,C.c44,C.c3T,C.c3U,C.c3V])
x(A.jH,[C.c4_,C.c40,C.c3S,C.c3R,C.c3Q,C.c3W,C.c3X,C.avj,C.avi,C.avk,C.avl,C.avm,C.avn,C.avo,C.avp,C.avq,C.avh,C.avr,C.avs])
x(A.kM,[C.c3Z,C.avt])
w(C.qJ,A.ao)})()
A.k9(b.typeUniverse,JSON.parse('{"qJ":{"ao":[],"f":[]}}'))
var y=(function rtii(){var x=A.ak
return{p:x("G<f>"),P:x("U<e,@>"),f:x("U<@,@>"),K:x("a8"),N:x("e"),l:x("f"),q:x("t9"),y:x("O"),z:x("@"),g:x("Y<@>?"),X:x("a8?"),H:x("~")}})();(function constants(){D.agk=new A.ac(40,20,40,20)
D.alG=new A.aj(B.hO,14,B.bp,null,null)
D.amQ=new A.aW(null,null,null,"Order",null,null,null,null,null,null,null,null,null,null,null,null,!0,!0,!1,null,null,null,null,null,null,!0,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,!0,null,null,null,null)
D.anT=new A.aW(null,null,null,"Remarks",null,null,null,null,null,null,"Optional comments about your completed order",null,null,null,null,null,!0,!0,!1,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,!0,null,null,null,null)
D.bBO=new A.o("Failed to submit feedback",null,null,null,null,null,null,null,null,null,null)
D.brF=new A.c3(D.bBO,null,null,null,null,null,null,null,null,null,null,null,null,B.ab,!1,null,null,null,B.w,null)
D.bH3=new A.o("Thank you for your feedback",null,null,null,null,null,null,null,null,null,null)
D.brZ=new A.c3(D.bH3,null,null,null,null,null,null,null,null,null,null,null,null,B.ab,!1,null,null,null,B.w,null)
D.bEg=new A.o("No delivered restaurant orders available for feedback",null,null,null,null,null,null,null,null,null,null)
D.bs_=new A.c3(D.bEg,null,null,null,null,null,null,null,null,null,null,null,null,B.ab,!1,null,null,null,B.w,null)
D.bH8=new A.o("Please log in to submit feedback",null,null,null,null,null,null,null,null,null,null)
D.bs0=new A.c3(D.bH8,null,null,null,null,null,null,null,null,null,null,null,null,B.ab,!1,null,null,null,B.w,null)
D.bIe=new A.o("Could not load your orders",null,null,null,null,null,null,null,null,null,null)
D.a18=new A.c3(D.bIe,null,null,null,null,null,null,null,null,null,null,null,null,B.ab,!1,null,null,null,B.w,null)
D.abu=new A.P(1,0.12156862745098039,0.1607843137254902,0.21568627450980393,B.F)
D.buS=new A.M(!0,D.abu,null,null,null,null,14,null,null,null,null,null,1.55,null,null,null,null,null,null,null,null,null,null,null,null,null)
D.bx1=new A.M(!0,B.T,null,null,null,null,null,B.a9,null,null,null,null,null,null,null,null,null,B.eS,B.T,null,null,null,null,null,null,null)
D.aaE=new A.P(1,0.9098039215686274,0.9176470588235294,0.9294117647058824,B.F)
D.byK=new A.M(!0,D.aaE,null,null,null,null,11,null,null,null,null,null,1.4,null,null,null,null,null,null,null,null,null,null,null,null,null)
D.mJ=new A.M(!0,B.x_,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null)
D.bBh=new A.o("Log in",null,null,null,null,null,null,null,null,null,null)
D.bE9=new A.o("Please log in to share feedback on a completed order.",null,null,null,null,null,null,null,null,null,null)
D.bF0=new A.o("Feedback",null,null,null,null,null,null,null,null,null,null)
D.btQ=new A.M(!0,B.bp,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null)
D.bGh=new A.o("Edit",null,D.btQ,null,null,null,null,null,null,null,null)
D.bGR=new A.o("How was this restaurant order?",null,null,null,null,null,null,null,null,null,null)
D.bJ6=new A.o("Feedback",null,D.mJ,null,null,null,null,null,null,null,null)})()};
(a=>{a["adBcLZL1EsPEPkyojE3uMnoxbAw="]=a.current})($__dart_deferred_initializers__);