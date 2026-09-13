((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,A,C,E,B={
Eh(d,e,f){return B.cFn(d,e,f)},
cFn(a5,a6,a7){var x=0,w=A.m(y.H),v,u=2,t=[],s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,a0,a1,a2,a3,a4
var $async$Eh=A.n(function(a9,b0){if(a9===1){t.push(b0)
x=u}for(;;)switch(x){case 0:a1={}
x=!a6?3:4
break
case 3:x=5
return A.d(A.bj(null,null,!0,null,new B.c2q(a5,a7),a5,null,!0,!0,y.z),$async$Eh)
case 5:x=1
break
case 4:a4=A
x=6
return A.d(A.d1(),$async$Eh)
case 6:s=a4.aJ(b0.a.h(0,"customer_token"))
if(s==null||s.length===0){if(a5.e!=null)a5.R(y.q).f.aE(D.brk)
x=1
break}j=a1.a=C.cx
u=8
j=y.N
x=11
return A.d(A.h8(A.bz("https://curatering.up.railway.app/api/restaurant/orders",0,null),A.N(["Authorization","Bearer "+s,"Content-Type","application/json"],j,j)).cI(C.lz),$async$Eh)
case 11:r=b0
if(r.b!==200){if(a5.e!=null)a5.R(y.q).f.aE(D.a12)
x=1
break}j=r
q=C.a6.bt(A.cw(A.cv(j.e)).b9(j.w),null)
i=y.g.a(J.t(q,"orders"))
p=i==null?C.bz:i
j=J.eh(p,y.f)
j=A.dh(j,new B.c2r(),j.$ti.i("r.E"),y.P)
h=A.y(j).i("Q<r.E>")
g=A.u(new A.Q(j,new B.c2s(),h),h.i("r.E"))
a1.a=g
j=g
u=2
x=10
break
case 8:u=7
a2=t.pop()
if(a5.e!=null)a5.R(y.q).f.aE(D.a12)
x=1
break
x=10
break
case 7:x=2
break
case 10:if(j.length===0){if(a5.e!=null)a5.R(y.q).f.aE(D.brj)
x=1
break}if(a5.e==null){x=1
break}a1.b=C.f.ga9(j)
a1.c=5
j=$.W()
e=new A.ae(C.a3,j)
x=12
return A.d(A.bj(null,null,!0,null,new B.c2t(a1,e),a5,null,!0,!0,y.y),$async$Eh)
case 12:d=b0
o=C.e.l(e.a.a)
e.J$=j
e.I$=0
if(d!==!0||a5.e==null){x=1
break}j=a1.b.h(0,"id")
n=J.v(j==null?a1.b.h(0,"order_no"):j)
u=14
j=A.bz("https://curatering.up.railway.app/api/restaurant/orders/"+A.h(n)+"/feedback",0,null)
h=y.N
a0=A.N(["Authorization","Bearer "+s,"Content-Type","application/json"],h,h)
x=17
return A.d(A.es(j,C.a6.cs(A.N(["stars",a1.c,"remarks",o],h,y.K),null),null,a0),$async$Eh)
case 17:m=b0
if(a5.e==null){x=1
break}if(m.b===200)a5.R(y.q).f.aE(D.bri)
else{l="Failed to submit feedback"
try{a1=m
k=C.a6.bt(A.cw(A.cv(a1.e)).b9(a1.w),null)
if(y.f.b(k)&&k.h(0,"error")!=null)l=J.v(k.h(0,"error"))}catch(a8){}a5.R(y.q).f.aE(A.cV(null,null,null,null,null,C.x,null,A.c(l,null,null,null,null,null,null,null,null),null,C.ab,null,null,null,null,null,null,null,null,null,null))}u=2
x=16
break
case 14:u=13
a3=t.pop()
if(a5.e!=null)a5.R(y.q).f.aE(D.br_)
x=16
break
case 13:x=2
break
case 16:case 1:return A.k(v,w)
case 2:return A.j(t.at(-1),w)}})
return A.l($async$Eh,w)},
c2q:function c2q(d,e){this.a=d
this.b=e},
c2o:function c2o(d){this.a=d},
c2p:function c2p(d,e,f){this.a=d
this.b=e
this.c=f},
c2m:function c2m(){},
c2r:function c2r(){},
c2s:function c2s(){},
c2t:function c2t(d,e){this.a=d
this.b=e},
c2n:function c2n(d,e,f){this.a=d
this.b=e
this.c=f},
c2h:function c2h(){},
c2i:function c2i(d,e){this.a=d
this.b=e},
c2g:function c2g(d,e){this.a=d
this.b=e},
c2j:function c2j(d,e){this.a=d
this.b=e},
c2f:function c2f(d,e,f){this.a=d
this.b=e
this.c=f},
c2e:function c2e(d,e){this.a=d
this.b=e},
c2k:function c2k(d){this.a=d},
c2l:function c2l(d){this.a=d},
qI:function qI(d,e,f,g,h,i){var _=this
_.c=d
_.d=e
_.e=f
_.f=g
_.r=h
_.a=i},
avc:function avc(d,e){this.a=d
this.b=e},
av2:function av2(d,e){this.a=d
this.b=e},
av1:function av1(d){this.a=d},
av3:function av3(d,e,f){this.a=d
this.b=e
this.c=f},
av4:function av4(d,e){this.a=d
this.b=e},
av5:function av5(d,e){this.a=d
this.b=e},
av6:function av6(d,e){this.a=d
this.b=e},
av7:function av7(d,e){this.a=d
this.b=e},
av8:function av8(d,e){this.a=d
this.b=e},
av9:function av9(d,e){this.a=d
this.b=e},
av0:function av0(){},
ava:function ava(d,e){this.a=d
this.b=e},
avb:function avb(d,e){this.a=d
this.b=e},
ck7(d,e){var x,w
if(d!=null){x=C.e.l(J.v(d))
if(x.length!==0)return x}if(e!=null){x=C.e.l(J.v(e))
w=x.length
if(w>8)return C.e.bZ(x,w-8)
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
B.qI.prototype={
FX(d,e){var x=A.ec(e),w=y.X,v=A.kn(d,null,w),u=v==null?null:v.c.a
if((u==null?"":u)===x)return
F.ri(d,x,null,w,w)},
OE(d){return this.aXZ(d)},
aXZ(d){var x=0,w=A.m(y.H),v,u=2,t=[],s,r,q,p
var $async$OE=A.n(function(e,f){if(e===1){t.push(f)
x=u}for(;;)switch(x){case 0:q=C.e.l(d)
if(J.at(q)===0){x=1
break}u=4
x=7
return A.d(A.vA(A.z7(null,null,q,null,"mailto"),C.zh),$async$OE)
case 7:u=2
x=6
break
case 4:u=3
p=t.pop()
s=A.a7(p)
A.em().$1("Failed to open mailto: "+A.h(s))
x=6
break
case 3:x=2
break
case 6:case 1:return A.k(v,w)
case 2:return A.j(t.at(-1),w)}})
return A.l($async$OE,w)},
OF(d){return this.aY_(d)},
aY_(d){var x=0,w=A.m(y.H),v=1,u=[],t=this,s,r,q,p,o,n,m,l
var $async$OF=A.n(function(e,f){if(e===1){u.push(f)
x=v}for(;;)switch(x){case 0:o=C.e.l(t.c.go)
n=o.length!==0
m=n?o:C.e.l(d)
if(C.e.b8(m,"http://")||C.e.b8(m,"https://"))q=A.bz(m,0,null)
else q=A.bz(n?o:"https://www.facebook.com/3tavs",0,null)
s=q
v=3
x=6
return A.d(A.vA(s,C.o7),$async$OF)
case 6:v=1
x=5
break
case 3:v=2
l=u.pop()
r=A.a7(l)
A.em().$1("Failed to open Facebook: "+A.h(r))
x=5
break
case 2:x=1
break
case 5:return A.k(null,w)
case 1:return A.j(u.at(-1),w)}})
return A.l($async$OF,w)},
akE(d,e,f){var x=null,w=A.aT(d,C.w,x,18),v=f==null,u=A.K(A.a([w,C.al,A.F(A.c(e,x,x,x,x,A.A(x,x,C.wO,x,!v?C.eR:C.a8,C.bx,x,x,x,x,x,12,x,x,x,x,x,!0,x,x,x,x,x,x,x,x),x,x,x),1)],y.p),C.E,C.l,C.q,0,x)
return v?u:A.cD(!1,x,!0,u,x,!0,x,x,x,x,x,x,x,x,x,x,f,x,x,x,x,x,x,x)},
a1i(d,e){return this.akE(d,e,null)},
D(d){var x=null
return A.P(x,A.dN(new B.avc(this,this.c)),C.v,C.nr,x,x,x,x,x,D.afN,x,x,x)}}
var z=a.updateTypes(["m2(S)"])
B.c2q.prototype={
$1(d){var x=null
return A.cL(A.a([A.bt(C.bR,x,x,x,new B.c2o(d),x,x),A.df(D.bAv,new B.c2p(d,this.a,this.b),x)],y.p),x,x,x,D.bDh,x,x,x,D.bE6,x)},
$S:10}
B.c2o.prototype={
$0(){A.R(this.a,!1).a2(null)
return null},
$S:0}
B.c2p.prototype={
$0(){var x=0,w=A.m(y.H),v=this
var $async$$0=A.n(function(d,e){if(d===1)return A.j(e,w)
for(;;)switch(x){case 0:A.R(v.a,!1).a2(null)
x=2
return A.d(A.bj(null,null,!0,null,new B.c2m(),v.b,null,!0,!0,y.z),$async$$0)
case 2:x=3
return A.d(v.c.$0(),$async$$0)
case 3:return A.k(null,w)}})
return A.l($async$$0,w)},
$S:1}
B.c2m.prototype={
$1(d){return G.qt},
$S:z+0}
B.c2r.prototype={
$1(d){return A.az(d,y.N,y.z)},
$S:23}
B.c2s.prototype={
$1(d){var x,w=d.h(0,"status"),v=J.v(w==null?"":w).toLowerCase()
if(!J.i(v,"delivered"))return!1
x=d.h(0,"feedback_stars")
return x==null},
$S:17}
B.c2t.prototype={
$1(d){return new A.dT(new B.c2n(this.a,this.b,d),null)},
$S:20}
B.c2n.prototype={
$2(d,e){var x,w,v=null,u=this.a,t=u.b,s=A.c("Feedback \xb7 "+B.ck7(t.h(0,"order_no"),t.h(0,"id")),v,v,v,v,v,v,v,v),r=y.p,q=A.a([],r),p=u.a
if(p.length>1){x=u.b
w=A.E(p).i("w<1,ax<U<e,@>>>")
p=A.u(new A.w(p,new B.c2h(),w),w.i("aa.E"))
C.f.t(q,A.a([A.ew(D.amh,v,v,v,!0,!1,p,v,new B.c2i(u,e),v,x,y.P),C.K],r))}q.push(D.bFX)
q.push(C.D)
q.push(A.K(A.hI(5,new B.c2j(u,e),!0,y.l),C.u,C.l,C.q,0,v))
q.push(C.D)
q.push(A.aE(v,C.P,!1,v,!0,C.x,v,A.aF(),this.b,v,v,v,v,v,2,D.anj,C.A,!0,v,!0,v,!1,v,C.a2,v,v,v,v,v,v,v,v,4,v,v,!1,"\u2022",v,v,v,v,v,!1,v,v,!1,v,!0,v,C.T,v,v,v,v,v,v,v,v,v,v,v,v,!0,C.L,v,C.S,v,v,v,v))
u=A.bs(A.x(q,C.E,C.l,C.a1,0,C.t),v,C.A,v,v,v,C.a0)
q=this.c
return A.cL(A.a([A.bt(C.bR,v,v,v,new B.c2k(q),v,v),A.df(C.pd,new B.c2l(q),v)],r),v,v,v,u,v,v,v,s,v)},
$S:47}
B.c2h.prototype={
$1(d){var x=null
return A.dZ(A.c(B.ck7(d.h(0,"order_no"),d.h(0,"id")),x,x,x,x,x,x,x,x),d,y.P)},
$S:1171}
B.c2i.prototype={
$1(d){if(d==null)return
this.b.$1(new B.c2g(this.a,d))},
$S:1172}
B.c2g.prototype={
$0(){return this.a.b=this.b},
$S:0}
B.c2j.prototype={
$1(d){var x=null,w=this.a,v=d<w.c,u=v?C.jc:C.nY
return A.aP(x,x,x,A.aT(u,v?C.mi:x,x,x),x,x,new B.c2f(w,this.b,d),x,20,x,x,C.dK)},
$S:174}
B.c2f.prototype={
$0(){return this.b.$1(new B.c2e(this.a,this.c))},
$S:0}
B.c2e.prototype={
$0(){return this.a.c=this.b+1},
$S:0}
B.c2k.prototype={
$0(){A.R(this.a,!1).a2(!1)
return null},
$S:0}
B.c2l.prototype={
$0(){A.R(this.a,!1).a2(!0)
return null},
$S:0}
B.avc.prototype={
$2(d,e){var x,w,v,u,t,s=null,r=e.b>900,q=r?s:220,p=this.b,o=y.p,n=A.a([A.bt(A.c(p.fr,s,s,s,s,D.bwd,s,s,s),s,s,s,new B.av2(d,p),s,s),A.kx(D.bxV,C.L,p.y1)],o),m=this.a
if(m.d)n.push(A.hm(D.al8,D.bFm,new B.av3(m,d,p),s))
q=A.ag(A.x(n,C.E,C.l,C.q,0,C.t),s,q)
n=A.x(A.a([A.bt(A.c("Gallery",s,s,s,s,D.mI,s,s,s),s,s,s,new B.av4(m,d),s,s),A.bt(A.c("Catering Menu",s,s,s,s,D.mI,s,s,s),s,s,s,new B.av5(m,d),s,s),A.bt(A.c("Restaurant",s,s,s,s,D.mI,s,s,s),s,s,s,new B.av6(m,d),s,s)],o),C.E,C.l,C.q,0,C.t)
x=A.x(A.a([A.bt(A.c("Inquire Now",s,s,s,s,D.mI,s,s,s),s,s,s,new B.av7(m,d),s,s),A.bt(A.c("Contact Us",s,s,s,s,D.mI,s,s,s),s,s,s,new B.av8(m,d),s,s),A.bt(D.bIe,s,s,s,new B.av9(m,d),s,s)],o),C.E,C.l,C.q,0,C.t)
w=p.rx
v=A.aT(E.yF,C.w,s,18)
w=A.cD(!1,s,!0,A.K(A.a([v,C.al,A.F(A.c(w,s,s,s,s,A.A(s,s,C.w,s,C.eR,C.bx,s,s,s,s,s,12,s,s,s,s,s,!0,s,s,s,s,s,s,s,s),s,s,s),1)],o),C.E,C.l,C.q,0,s),s,!0,s,s,s,s,s,s,s,s,s,s,new B.ava(m,p),s,s,s,s,s,s,s)
u=A.a([q,n,x,A.ag(w,s,200),A.x(A.a([m.a1i(E.yO,p.ry),m.a1i(E.yR,p.to)],o),C.E,C.l,C.q,0,C.t),A.x(A.a([m.a1i(E.r4,p.x1),m.akE(E.yE,p.x2,new B.avb(m,p))],o),C.E,C.l,C.q,0,C.t)],o)
if(r){q=A.a([],o)
for(t=0;t<6;++t){p=A.a([],o)
if(t>0)p.push(D.bqb)
p.push(new A.dR(1,C.c8,u[t],s))
C.f.t(q,p)}q.push(C.cD)
q.push(A.n8("lib/assets/main-2.png",C.ar,C.dm,C.c7,72,s))
return A.K(q,C.E,C.l,C.q,0,s)}return A.cn(C.aU,u,C.aX,12,24)},
$S:1173}
B.av2.prototype={
$0(){var x=this.a,w=this.b,v=w.fr,u=w.fx
w=A.b6("\\[color=#0{3,8}\\]",!1,!1,!1)
u=A.bO(u,w,"")
w=A.b6("\\[color=#1[Ee]1[Ee]1[Ee]\\]",!1,!1,!1)
u=A.bO(u,w,"")
w=A.b6("\\[color=#262626\\]",!1,!1,!1)
u=A.bO(u,w,"")
w=A.b6("\\[color=black\\]",!1,!1,!1)
u=A.bO(u,w,"")
u=A.bO(u,"[/color]","")
w=A.b6("color\\s*:\\s*#0{3,8}\\s*;?",!1,!1,!1)
u=A.bO(u,w,"")
w=A.b6("color\\s*:\\s*black\\s*;?",!1,!1,!1)
w=A.kx(D.bu6,C.L,A.bO(u,w,""))
A.et(A.a([new A.dx("Close",null,new B.av1(x),!1,null)],y.p),!0,w,x,560,!0,v,y.H)},
$S:0}
B.av1.prototype={
$0(){A.R(this.a,!1).a2(null)
return null},
$S:0}
B.av3.prototype={
$0(){var x=0,w=A.m(y.H),v,u=this,t,s
var $async$$0=A.n(function(d,e){if(d===1)return A.j(e,w)
for(;;)switch(x){case 0:t=u.c
x=3
return A.d(A.tg(u.b,t.y1,"Edit footer copyright"),$async$$0)
case 3:s=e
if(s==null||s.length===0){x=1
break}t.y1=s
x=4
return A.d(t.hD(),$async$$0)
case 4:t=u.a.r
if(t!=null)t.$0()
case 1:return A.k(v,w)}})
return A.l($async$$0,w)},
$S:1}
B.av4.prototype={
$0(){return this.a.FX(this.b,"/gallery")},
$S:0}
B.av5.prototype={
$0(){return this.a.FX(this.b,"/catering-menu")},
$S:0}
B.av6.prototype={
$0(){return this.a.FX(this.b,"/restaurant")},
$S:0}
B.av7.prototype={
$0(){return this.a.FX(this.b,"/inquire")},
$S:0}
B.av8.prototype={
$0(){return this.a.FX(this.b,"/contact-us")},
$S:0}
B.av9.prototype={
$0(){var x=this.a,w=x.f
if(w==null)w=new B.av0()
return B.Eh(this.b,x.e,w)},
$S:0}
B.av0.prototype={
$0(){var x=0,w=A.m(y.H)
var $async$$0=A.n(function(d,e){if(d===1)return A.j(e,w)
for(;;)switch(x){case 0:return A.k(null,w)}})
return A.l($async$$0,w)},
$S:1}
B.ava.prototype={
$0(){return this.a.OF(this.b.rx)},
$S:0}
B.avb.prototype={
$0(){return this.a.OE(this.b.x2)},
$S:0};(function inheritance(){var x=a.inheritMany,w=a.inherit
x(A.ht,[B.c2q,B.c2m,B.c2r,B.c2s,B.c2t,B.c2h,B.c2i,B.c2j])
x(A.jC,[B.c2o,B.c2p,B.c2g,B.c2f,B.c2e,B.c2k,B.c2l,B.av2,B.av1,B.av3,B.av4,B.av5,B.av6,B.av7,B.av8,B.av9,B.av0,B.ava,B.avb])
x(A.kJ,[B.c2n,B.avc])
w(B.qI,A.ap)})()
A.kB(b.typeUniverse,JSON.parse('{"qI":{"ap":[],"f":[]}}'))
var y=(function rtii(){var x=A.ak
return{p:x("G<f>"),P:x("U<e,@>"),f:x("U<@,@>"),K:x("a8"),N:x("e"),l:x("f"),q:x("t8"),y:x("O"),z:x("@"),g:x("a_<@>?"),X:x("a8?"),H:x("~")}})();(function constants(){D.afN=new A.ac(40,20,40,20)
D.al8=new A.aj(C.hN,14,C.bx,null,null)
D.amh=new A.aV(null,null,null,"Order",null,null,null,null,null,null,null,null,null,null,null,null,!0,!0,!1,null,null,null,null,null,null,!0,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,!0,null,null,null,null)
D.anj=new A.aV(null,null,null,"Remarks",null,null,null,null,null,null,"Optional comments about your completed order",null,null,null,null,null,!0,!0,!1,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,!0,null,null,null,null)
D.bqb=new A.bn(28,null,null,null)
D.bB3=new A.o("Failed to submit feedback",null,null,null,null,null,null,null,null,null,null)
D.br_=new A.c8(D.bB3,null,null,null,null,null,null,null,null,null,null,null,null,C.ab,!1,null,null,null,C.x,null)
D.bG9=new A.o("Thank you for your feedback",null,null,null,null,null,null,null,null,null,null)
D.bri=new A.c8(D.bG9,null,null,null,null,null,null,null,null,null,null,null,null,C.ab,!1,null,null,null,C.x,null)
D.bDn=new A.o("No delivered restaurant orders available for feedback",null,null,null,null,null,null,null,null,null,null)
D.brj=new A.c8(D.bDn,null,null,null,null,null,null,null,null,null,null,null,null,C.ab,!1,null,null,null,C.x,null)
D.bGd=new A.o("Please log in to submit feedback",null,null,null,null,null,null,null,null,null,null)
D.brk=new A.c8(D.bGd,null,null,null,null,null,null,null,null,null,null,null,null,C.ab,!1,null,null,null,C.x,null)
D.bHm=new A.o("Could not load your orders",null,null,null,null,null,null,null,null,null,null)
D.a12=new A.c8(D.bHm,null,null,null,null,null,null,null,null,null,null,null,null,C.ab,!1,null,null,null,C.x,null)
D.ab3=new A.T(1,0.12156862745098039,0.1607843137254902,0.21568627450980393,C.H)
D.bu6=new A.L(!0,D.ab3,null,null,null,null,14,null,null,null,null,null,1.55,null,null,null,null,null,null,null,null,null,null,null,null,null)
D.bwd=new A.L(!0,C.W,null,null,null,null,null,C.aa,null,null,null,null,null,null,null,null,null,C.eR,C.W,null,null,null,null,null,null,null)
D.aag=new A.T(1,0.9098039215686274,0.9176470588235294,0.9294117647058824,C.H)
D.bxV=new A.L(!0,D.aag,null,null,null,null,11,null,null,null,null,null,1.4,null,null,null,null,null,null,null,null,null,null,null,null,null)
D.mI=new A.L(!0,C.wO,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null)
D.bAv=new A.o("Log in",null,null,null,null,null,null,null,null,null,null)
D.bDh=new A.o("Please log in to share feedback on a completed order.",null,null,null,null,null,null,null,null,null,null)
D.bE6=new A.o("Feedback",null,null,null,null,null,null,null,null,null,null)
D.bFm=new A.o("Edit",null,H.a1E,null,null,null,null,null,null,null,null)
D.bFX=new A.o("How was this restaurant order?",null,null,null,null,null,null,null,null,null,null)
D.bIe=new A.o("Feedback",null,D.mI,null,null,null,null,null,null,null,null)})()};
(a=>{a["+hneh68Dy1wDKPyr8ApKToaDBpc="]=a.current})($__dart_deferred_initializers__);