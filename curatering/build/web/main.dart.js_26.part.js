((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,A,C,E,B={
Ei(d,e,f){return B.cFN(d,e,f)},
cFN(a5,a6,a7){var x=0,w=A.l(y.H),v,u=2,t=[],s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,a0,a1,a2,a3,a4
var $async$Ei=A.m(function(a9,b0){if(a9===1){t.push(b0)
x=u}for(;;)switch(x){case 0:a1={}
x=!a6?3:4
break
case 3:x=5
return A.d(A.bh(null,null,!0,null,new B.c2R(a5,a7),a5,null,!0,!0,y.z),$async$Ei)
case 5:x=1
break
case 4:a4=A
x=6
return A.d(A.d1(),$async$Ei)
case 6:s=a4.aK(b0.a.h(0,"customer_token"))
if(s==null||s.length===0){if(a5.e!=null)a5.R(y.q).f.aE(D.brm)
x=1
break}j=a1.a=C.cx
u=8
j=y.N
x=11
return A.d(A.fE(A.bx("https://curatering.up.railway.app/api/restaurant/orders",0,null),A.N(["Authorization","Bearer "+s,"Content-Type","application/json"],j,j)).cz(C.lA),$async$Ei)
case 11:r=b0
if(r.b!==200){if(a5.e!=null)a5.R(y.q).f.aE(D.a13)
x=1
break}j=r
q=C.a6.bq(A.ch(A.cg(j.e)).b6(j.w),null)
i=y.g.a(J.t(q,"orders"))
p=i==null?C.bA:i
j=J.ei(p,y.f)
j=A.dg(j,new B.c2S(),j.$ti.i("r.E"),y.P)
h=A.y(j).i("T<r.E>")
g=A.v(new A.T(j,new B.c2T(),h),h.i("r.E"))
a1.a=g
j=g
u=2
x=10
break
case 8:u=7
a2=t.pop()
if(a5.e!=null)a5.R(y.q).f.aE(D.a13)
x=1
break
x=10
break
case 7:x=2
break
case 10:if(j.length===0){if(a5.e!=null)a5.R(y.q).f.aE(D.brl)
x=1
break}if(a5.e==null){x=1
break}a1.b=C.f.ga9(j)
a1.c=5
j=$.W()
e=new A.ae(C.a3,j)
x=12
return A.d(A.bh(null,null,!0,null,new B.c2U(a1,e),a5,null,!0,!0,y.y),$async$Ei)
case 12:d=b0
o=C.e.l(e.a.a)
e.J$=j
e.I$=0
if(d!==!0||a5.e==null){x=1
break}j=a1.b.h(0,"id")
n=J.u(j==null?a1.b.h(0,"order_no"):j)
u=14
j=A.bx("https://curatering.up.railway.app/api/restaurant/orders/"+A.h(n)+"/feedback",0,null)
h=y.N
a0=A.N(["Authorization","Bearer "+s,"Content-Type","application/json"],h,h)
x=17
return A.d(A.es(j,C.a6.co(A.N(["stars",a1.c,"remarks",o],h,y.K),null),null,a0),$async$Ei)
case 17:m=b0
if(a5.e==null){x=1
break}if(m.b===200)a5.R(y.q).f.aE(D.brk)
else{l="Failed to submit feedback"
try{a1=m
k=C.a6.bq(A.ch(A.cg(a1.e)).b6(a1.w),null)
if(y.f.b(k)&&k.h(0,"error")!=null)l=J.u(k.h(0,"error"))}catch(a8){}a5.R(y.q).f.aE(A.cV(null,null,null,null,null,C.x,null,A.c(l,null,null,null,null,null,null,null,null),null,C.ab,null,null,null,null,null,null,null,null,null,null))}u=2
x=16
break
case 14:u=13
a3=t.pop()
if(a5.e!=null)a5.R(y.q).f.aE(D.br1)
x=16
break
case 13:x=2
break
case 16:case 1:return A.j(v,w)
case 2:return A.i(t.at(-1),w)}})
return A.k($async$Ei,w)},
c2R:function c2R(d,e){this.a=d
this.b=e},
c2P:function c2P(d){this.a=d},
c2Q:function c2Q(d,e,f){this.a=d
this.b=e
this.c=f},
c2N:function c2N(){},
c2S:function c2S(){},
c2T:function c2T(){},
c2U:function c2U(d,e){this.a=d
this.b=e},
c2O:function c2O(d,e,f){this.a=d
this.b=e
this.c=f},
c2I:function c2I(){},
c2J:function c2J(d,e){this.a=d
this.b=e},
c2H:function c2H(d,e){this.a=d
this.b=e},
c2K:function c2K(d,e){this.a=d
this.b=e},
c2G:function c2G(d,e,f){this.a=d
this.b=e
this.c=f},
c2F:function c2F(d,e){this.a=d
this.b=e},
c2L:function c2L(d){this.a=d},
c2M:function c2M(d){this.a=d},
qK:function qK(d,e,f,g,h,i){var _=this
_.c=d
_.d=e
_.e=f
_.f=g
_.r=h
_.a=i},
avh:function avh(d,e){this.a=d
this.b=e},
av7:function av7(d,e){this.a=d
this.b=e},
av6:function av6(d){this.a=d},
av8:function av8(d,e,f){this.a=d
this.b=e
this.c=f},
av9:function av9(d,e){this.a=d
this.b=e},
ava:function ava(d,e){this.a=d
this.b=e},
avb:function avb(d,e){this.a=d
this.b=e},
avc:function avc(d,e){this.a=d
this.b=e},
avd:function avd(d,e){this.a=d
this.b=e},
ave:function ave(d,e){this.a=d
this.b=e},
av5:function av5(){},
avf:function avf(d,e){this.a=d
this.b=e},
avg:function avg(d,e){this.a=d
this.b=e},
ckx(d,e){var x,w
if(d!=null){x=C.e.l(J.u(d))
if(x.length!==0)return x}if(e!=null){x=C.e.l(J.u(e))
w=x.length
if(w>8)return C.e.c_(x,w-8)
if(w!==0)return x}return"N/A"}},D,F,G,H
J=c[1]
A=c[0]
C=c[2]
E=c[41]
B=a.updateHolder(c[24],B)
D=c[61]
F=c[27]
G=c[32]
H=c[47]
B.qK.prototype={
G_(d,e){var x=A.ec(e),w=y.X,v=A.kp(d,null,w),u=v==null?null:v.c.a
if((u==null?"":u)===x)return
F.rk(d,x,null,w,w)},
OJ(d){return this.aYd(d)},
aYd(d){var x=0,w=A.l(y.H),v,u=2,t=[],s,r,q,p
var $async$OJ=A.m(function(e,f){if(e===1){t.push(f)
x=u}for(;;)switch(x){case 0:q=C.e.l(d)
if(J.at(q)===0){x=1
break}u=4
x=7
return A.d(A.vC(A.z9(null,null,q,null,"mailto"),C.zk),$async$OJ)
case 7:u=2
x=6
break
case 4:u=3
p=t.pop()
s=A.a5(p)
A.em().$1("Failed to open mailto: "+A.h(s))
x=6
break
case 3:x=2
break
case 6:case 1:return A.j(v,w)
case 2:return A.i(t.at(-1),w)}})
return A.k($async$OJ,w)},
OK(d){return this.aYe(d)},
aYe(d){var x=0,w=A.l(y.H),v=1,u=[],t=this,s,r,q,p,o,n,m,l
var $async$OK=A.m(function(e,f){if(e===1){u.push(f)
x=v}for(;;)switch(x){case 0:o=C.e.l(t.c.go)
n=o.length!==0
m=n?o:C.e.l(d)
if(C.e.b8(m,"http://")||C.e.b8(m,"https://"))q=A.bx(m,0,null)
else q=A.bx(n?o:"https://www.facebook.com/3tavs",0,null)
s=q
v=3
x=6
return A.d(A.vC(s,C.o9),$async$OK)
case 6:v=1
x=5
break
case 3:v=2
l=u.pop()
r=A.a5(l)
A.em().$1("Failed to open Facebook: "+A.h(r))
x=5
break
case 2:x=1
break
case 5:return A.j(null,w)
case 1:return A.i(u.at(-1),w)}})
return A.k($async$OK,w)},
akN(d,e,f){var x=null,w=A.aT(d,C.w,x,18),v=f==null,u=A.K(A.a([w,C.al,A.F(A.c(e,x,x,x,x,A.A(x,x,C.wR,x,!v?C.eS:C.a8,C.by,x,x,x,x,x,12,x,x,x,x,x,!0,x,x,x,x,x,x,x,x),x,x,x),1)],y.p),C.E,C.k,C.q,0,x)
return v?u:A.cA(!1,x,!0,u,x,!0,x,x,x,x,x,x,x,x,x,x,f,x,x,x,x,x,x,x)},
a1o(d,e){return this.akN(d,e,null)},
D(d){var x=null
return A.P(x,A.dN(new B.avh(this,this.c)),C.v,C.ns,x,x,x,x,x,x,D.afN,x,x,x)}}
var z=a.updateTypes(["m4(R)"])
B.c2R.prototype={
$1(d){var x=null
return A.cM(A.a([A.bt(C.bR,x,x,x,new B.c2P(d),x,x),A.de(D.bAy,new B.c2Q(d,this.a,this.b),x)],y.p),x,x,x,D.bDl,x,x,x,D.bEa,x)},
$S:10}
B.c2P.prototype={
$0(){A.Q(this.a,!1).a2(null)
return null},
$S:0}
B.c2Q.prototype={
$0(){var x=0,w=A.l(y.H),v=this
var $async$$0=A.m(function(d,e){if(d===1)return A.i(e,w)
for(;;)switch(x){case 0:A.Q(v.a,!1).a2(null)
x=2
return A.d(A.bh(null,null,!0,null,new B.c2N(),v.b,null,!0,!0,y.z),$async$$0)
case 2:x=3
return A.d(v.c.$0(),$async$$0)
case 3:return A.j(null,w)}})
return A.k($async$$0,w)},
$S:1}
B.c2N.prototype={
$1(d){return G.qv},
$S:z+0}
B.c2S.prototype={
$1(d){return A.ax(d,y.N,y.z)},
$S:24}
B.c2T.prototype={
$1(d){var x,w=d.h(0,"status"),v=J.u(w==null?"":w).toLowerCase()
if(!J.n(v,"delivered"))return!1
x=d.h(0,"feedback_stars")
return x==null},
$S:17}
B.c2U.prototype={
$1(d){return new A.dU(new B.c2O(this.a,this.b,d),null)},
$S:20}
B.c2O.prototype={
$2(d,e){var x,w,v=null,u=this.a,t=u.b,s=A.c("Feedback \xb7 "+B.ckx(t.h(0,"order_no"),t.h(0,"id")),v,v,v,v,v,v,v,v),r=y.p,q=A.a([],r),p=u.a
if(p.length>1){x=u.b
w=A.E(p).i("w<1,ay<U<e,@>>>")
p=A.v(new A.w(p,new B.c2I(),w),w.i("aa.E"))
C.f.t(q,A.a([A.ew(D.amg,v,v,v,!0,!1,p,v,new B.c2J(u,e),v,x,y.P),C.K],r))}q.push(D.bG2)
q.push(C.D)
q.push(A.K(A.hL(5,new B.c2K(u,e),!0,y.l),C.u,C.k,C.q,0,v))
q.push(C.D)
q.push(A.aE(v,C.O,!1,v,!0,C.x,v,A.aF(),this.b,v,v,v,v,v,2,D.anj,C.A,!0,v,!0,v,!1,v,C.a2,v,v,v,v,v,v,v,v,4,v,v,!1,"\u2022",v,v,v,v,v,!1,v,v,!1,v,!0,v,C.T,v,v,v,v,v,v,v,v,v,v,v,v,!0,C.L,v,C.S,v,v,v,v))
u=A.bs(A.x(q,C.E,C.k,C.a1,0,C.t),v,C.A,v,v,v,C.a0)
q=this.c
return A.cM(A.a([A.bt(C.bR,v,v,v,new B.c2L(q),v,v),A.de(C.pf,new B.c2M(q),v)],r),v,v,v,u,v,v,v,s,v)},
$S:45}
B.c2I.prototype={
$1(d){var x=null
return A.e_(A.c(B.ckx(d.h(0,"order_no"),d.h(0,"id")),x,x,x,x,x,x,x,x),d,y.P)},
$S:1171}
B.c2J.prototype={
$1(d){if(d==null)return
this.b.$1(new B.c2H(this.a,d))},
$S:1172}
B.c2H.prototype={
$0(){return this.a.b=this.b},
$S:0}
B.c2K.prototype={
$1(d){var x=null,w=this.a,v=d<w.c,u=v?C.je:C.o_
return A.aP(x,x,x,A.aT(u,v?C.mj:x,x,x),x,x,new B.c2G(w,this.b,d),x,20,x,x,C.dL)},
$S:175}
B.c2G.prototype={
$0(){return this.b.$1(new B.c2F(this.a,this.c))},
$S:0}
B.c2F.prototype={
$0(){return this.a.c=this.b+1},
$S:0}
B.c2L.prototype={
$0(){A.Q(this.a,!1).a2(!1)
return null},
$S:0}
B.c2M.prototype={
$0(){A.Q(this.a,!1).a2(!0)
return null},
$S:0}
B.avh.prototype={
$2(d,e){var x,w,v,u,t,s=null,r=e.b>900,q=r?s:220,p=this.b,o=y.p,n=A.a([A.bt(A.c(p.fr,s,s,s,s,D.bwg,s,s,s),s,s,s,new B.av7(d,p),s,s),A.kz(D.bxY,C.L,p.y1)],o),m=this.a
if(m.d)n.push(A.hm(D.al7,D.bFs,new B.av8(m,d,p),s))
q=A.af(A.x(n,C.E,C.k,C.q,0,C.t),s,q)
n=A.x(A.a([A.bt(A.c("Gallery",s,s,s,s,D.mJ,s,s,s),s,s,s,new B.av9(m,d),s,s),A.bt(A.c("Catering Menu",s,s,s,s,D.mJ,s,s,s),s,s,s,new B.ava(m,d),s,s),A.bt(A.c("Restaurant",s,s,s,s,D.mJ,s,s,s),s,s,s,new B.avb(m,d),s,s)],o),C.E,C.k,C.q,0,C.t)
x=A.x(A.a([A.bt(A.c("Inquire Now",s,s,s,s,D.mJ,s,s,s),s,s,s,new B.avc(m,d),s,s),A.bt(A.c("Contact Us",s,s,s,s,D.mJ,s,s,s),s,s,s,new B.avd(m,d),s,s),A.bt(D.bIk,s,s,s,new B.ave(m,d),s,s)],o),C.E,C.k,C.q,0,C.t)
w=p.rx
v=A.aT(E.yJ,C.w,s,18)
w=A.cA(!1,s,!0,A.K(A.a([v,C.al,A.F(A.c(w,s,s,s,s,A.A(s,s,C.w,s,C.eS,C.by,s,s,s,s,s,12,s,s,s,s,s,!0,s,s,s,s,s,s,s,s),s,s,s),1)],o),C.E,C.k,C.q,0,s),s,!0,s,s,s,s,s,s,s,s,s,s,new B.avf(m,p),s,s,s,s,s,s,s)
u=A.a([q,n,x,A.af(w,s,200),A.x(A.a([m.a1o(E.yS,p.ry),m.a1o(E.yV,p.to)],o),C.E,C.k,C.q,0,C.t),A.x(A.a([m.a1o(E.r4,p.x1),m.akN(E.yI,p.x2,new B.avg(m,p))],o),C.E,C.k,C.q,0,C.t)],o)
if(r){q=A.a([],o)
for(t=0;t<6;++t){p=A.a([],o)
if(t>0)p.push(D.bqd)
p.push(new A.dR(1,C.c8,u[t],s))
C.f.t(q,p)}q.push(C.cD)
q.push(A.na("lib/assets/main-2.png",C.as,C.dm,C.c4,72,s))
return A.K(q,C.E,C.k,C.q,0,s)}return A.cq(C.aU,u,C.aX,12,24)},
$S:1173}
B.av7.prototype={
$0(){var x=this.a,w=this.b,v=w.fr,u=w.fx
w=A.b4("\\[color=#0{3,8}\\]",!1,!1,!1)
u=A.bL(u,w,"")
w=A.b4("\\[color=#1[Ee]1[Ee]1[Ee]\\]",!1,!1,!1)
u=A.bL(u,w,"")
w=A.b4("\\[color=#262626\\]",!1,!1,!1)
u=A.bL(u,w,"")
w=A.b4("\\[color=black\\]",!1,!1,!1)
u=A.bL(u,w,"")
u=A.bL(u,"[/color]","")
w=A.b4("color\\s*:\\s*#0{3,8}\\s*;?",!1,!1,!1)
u=A.bL(u,w,"")
w=A.b4("color\\s*:\\s*black\\s*;?",!1,!1,!1)
w=A.kz(D.bu8,C.L,A.bL(u,w,""))
A.et(A.a([new A.dy("Close",null,new B.av6(x),!1,null)],y.p),!0,w,x,560,!0,v,y.H)},
$S:0}
B.av6.prototype={
$0(){A.Q(this.a,!1).a2(null)
return null},
$S:0}
B.av8.prototype={
$0(){var x=0,w=A.l(y.H),v,u=this,t,s
var $async$$0=A.m(function(d,e){if(d===1)return A.i(e,w)
for(;;)switch(x){case 0:t=u.c
x=3
return A.d(A.ti(u.b,t.y1,"Edit footer copyright"),$async$$0)
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
B.av9.prototype={
$0(){return this.a.G_(this.b,"/gallery")},
$S:0}
B.ava.prototype={
$0(){return this.a.G_(this.b,"/catering-menu")},
$S:0}
B.avb.prototype={
$0(){return this.a.G_(this.b,"/restaurant")},
$S:0}
B.avc.prototype={
$0(){return this.a.G_(this.b,"/inquire")},
$S:0}
B.avd.prototype={
$0(){return this.a.G_(this.b,"/contact-us")},
$S:0}
B.ave.prototype={
$0(){var x=this.a,w=x.f
if(w==null)w=new B.av5()
return B.Ei(this.b,x.e,w)},
$S:0}
B.av5.prototype={
$0(){var x=0,w=A.l(y.H)
var $async$$0=A.m(function(d,e){if(d===1)return A.i(e,w)
for(;;)switch(x){case 0:return A.j(null,w)}})
return A.k($async$$0,w)},
$S:1}
B.avf.prototype={
$0(){return this.a.OK(this.b.rx)},
$S:0}
B.avg.prototype={
$0(){return this.a.OJ(this.b.x2)},
$S:0};(function inheritance(){var x=a.inheritMany,w=a.inherit
x(A.ht,[B.c2R,B.c2N,B.c2S,B.c2T,B.c2U,B.c2I,B.c2J,B.c2K])
x(A.jD,[B.c2P,B.c2Q,B.c2H,B.c2G,B.c2F,B.c2L,B.c2M,B.av7,B.av6,B.av8,B.av9,B.ava,B.avb,B.avc,B.avd,B.ave,B.av5,B.avf,B.avg])
x(A.kK,[B.c2O,B.avh])
w(B.qK,A.aq)})()
A.kD(b.typeUniverse,JSON.parse('{"qK":{"aq":[],"f":[]}}'))
var y=(function rtii(){var x=A.ak
return{p:x("G<f>"),P:x("U<e,@>"),f:x("U<@,@>"),K:x("a8"),N:x("e"),l:x("f"),q:x("ta"),y:x("O"),z:x("@"),g:x("a_<@>?"),X:x("a8?"),H:x("~")}})();(function constants(){D.afN=new A.ac(40,20,40,20)
D.al7=new A.aj(C.hN,14,C.by,null,null)
D.amg=new A.aV(null,null,null,"Order",null,null,null,null,null,null,null,null,null,null,null,null,!0,!0,!1,null,null,null,null,null,null,!0,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,!0,null,null,null,null)
D.anj=new A.aV(null,null,null,"Remarks",null,null,null,null,null,null,"Optional comments about your completed order",null,null,null,null,null,!0,!0,!1,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,!0,null,null,null,null)
D.bqd=new A.bn(28,null,null,null)
D.bB6=new A.o("Failed to submit feedback",null,null,null,null,null,null,null,null,null,null)
D.br1=new A.c8(D.bB6,null,null,null,null,null,null,null,null,null,null,null,null,C.ab,!1,null,null,null,C.x,null)
D.bGf=new A.o("Thank you for your feedback",null,null,null,null,null,null,null,null,null,null)
D.brk=new A.c8(D.bGf,null,null,null,null,null,null,null,null,null,null,null,null,C.ab,!1,null,null,null,C.x,null)
D.bDr=new A.o("No delivered restaurant orders available for feedback",null,null,null,null,null,null,null,null,null,null)
D.brl=new A.c8(D.bDr,null,null,null,null,null,null,null,null,null,null,null,null,C.ab,!1,null,null,null,C.x,null)
D.bGj=new A.o("Please log in to submit feedback",null,null,null,null,null,null,null,null,null,null)
D.brm=new A.c8(D.bGj,null,null,null,null,null,null,null,null,null,null,null,null,C.ab,!1,null,null,null,C.x,null)
D.bHs=new A.o("Could not load your orders",null,null,null,null,null,null,null,null,null,null)
D.a13=new A.c8(D.bHs,null,null,null,null,null,null,null,null,null,null,null,null,C.ab,!1,null,null,null,C.x,null)
D.ab4=new A.S(1,0.12156862745098039,0.1607843137254902,0.21568627450980393,C.H)
D.bu8=new A.M(!0,D.ab4,null,null,null,null,14,null,null,null,null,null,1.55,null,null,null,null,null,null,null,null,null,null,null,null,null)
D.bwg=new A.M(!0,C.W,null,null,null,null,null,C.aa,null,null,null,null,null,null,null,null,null,C.eS,C.W,null,null,null,null,null,null,null)
D.aah=new A.S(1,0.9098039215686274,0.9176470588235294,0.9294117647058824,C.H)
D.bxY=new A.M(!0,D.aah,null,null,null,null,11,null,null,null,null,null,1.4,null,null,null,null,null,null,null,null,null,null,null,null,null)
D.mJ=new A.M(!0,C.wR,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null)
D.bAy=new A.o("Log in",null,null,null,null,null,null,null,null,null,null)
D.bDl=new A.o("Please log in to share feedback on a completed order.",null,null,null,null,null,null,null,null,null,null)
D.bEa=new A.o("Feedback",null,null,null,null,null,null,null,null,null,null)
D.bFs=new A.o("Edit",null,H.a1F,null,null,null,null,null,null,null,null)
D.bG2=new A.o("How was this restaurant order?",null,null,null,null,null,null,null,null,null,null)
D.bIk=new A.o("Feedback",null,D.mJ,null,null,null,null,null,null,null,null)})()};
(a=>{a["ENVsZzzBU2MQ03GPXVlYsn20kps="]=a.current})($__dart_deferred_initializers__);