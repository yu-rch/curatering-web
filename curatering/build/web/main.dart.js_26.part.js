((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,A,C,E,B={
Em(d,e,f){return B.cGD(d,e,f)},
cGD(a5,a6,a7){var x=0,w=A.l(y.H),v,u=2,t=[],s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,a0,a1,a2,a3,a4
var $async$Em=A.m(function(a9,b0){if(a9===1){t.push(b0)
x=u}for(;;)switch(x){case 0:a1={}
x=!a6?3:4
break
case 3:x=5
return A.d(A.bf(null,null,!0,null,new B.c3E(a5,a7),a5,null,!0,!0,y.z),$async$Em)
case 5:x=1
break
case 4:a4=A
x=6
return A.d(A.d2(),$async$Em)
case 6:s=a4.aK(b0.a.h(0,"customer_token"))
if(s==null||s.length===0){if(a5.e!=null)a5.R(y.q).f.aA(D.brL)
x=1
break}j=a1.a=C.cz
u=8
j=y.N
x=11
return A.d(A.fG(A.bx("https://curatering.up.railway.app/api/restaurant/orders",0,null),A.N(["Authorization","Bearer "+s,"Content-Type","application/json"],j,j)).cz(C.lD),$async$Em)
case 11:r=b0
if(r.b!==200){if(a5.e!=null)a5.R(y.q).f.aA(D.a1_)
x=1
break}j=r
q=C.a6.bq(A.cj(A.ci(j.e)).b7(j.w),null)
i=y.g.a(J.t(q,"orders"))
p=i==null?C.bA:i
j=J.ej(p,y.f)
j=A.dh(j,new B.c3F(),j.$ti.i("r.E"),y.P)
h=A.y(j).i("T<r.E>")
g=A.v(new A.T(j,new B.c3G(),h),h.i("r.E"))
a1.a=g
j=g
u=2
x=10
break
case 8:u=7
a2=t.pop()
if(a5.e!=null)a5.R(y.q).f.aA(D.a1_)
x=1
break
x=10
break
case 7:x=2
break
case 10:if(j.length===0){if(a5.e!=null)a5.R(y.q).f.aA(D.brK)
x=1
break}if(a5.e==null){x=1
break}a1.b=C.f.ga8(j)
a1.c=5
j=$.W()
e=new A.ae(C.a3,j)
x=12
return A.d(A.bf(null,null,!0,null,new B.c3H(a1,e),a5,null,!0,!0,y.y),$async$Em)
case 12:d=b0
o=C.e.l(e.a.a)
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
return A.d(A.et(j,C.a6.co(A.N(["stars",a1.c,"remarks",o],h,y.K),null),null,a0),$async$Em)
case 17:m=b0
if(a5.e==null){x=1
break}if(m.b===200)a5.R(y.q).f.aA(D.brJ)
else{l="Failed to submit feedback"
try{a1=m
k=C.a6.bq(A.cj(A.ci(a1.e)).b7(a1.w),null)
if(y.f.b(k)&&k.h(0,"error")!=null)l=J.u(k.h(0,"error"))}catch(a8){}a5.R(y.q).f.aA(A.cR(null,null,null,null,null,C.w,null,A.c(l,null,null,null,null,null,null,null,null),null,C.aa,null,null,null,null,null,null,null,null,null,null))}u=2
x=16
break
case 14:u=13
a3=t.pop()
if(a5.e!=null)a5.R(y.q).f.aA(D.brp)
x=16
break
case 13:x=2
break
case 16:case 1:return A.j(v,w)
case 2:return A.i(t.at(-1),w)}})
return A.k($async$Em,w)},
c3E:function c3E(d,e){this.a=d
this.b=e},
c3C:function c3C(d){this.a=d},
c3D:function c3D(d,e,f){this.a=d
this.b=e
this.c=f},
c3A:function c3A(){},
c3F:function c3F(){},
c3G:function c3G(){},
c3H:function c3H(d,e){this.a=d
this.b=e},
c3B:function c3B(d,e,f){this.a=d
this.b=e
this.c=f},
c3v:function c3v(){},
c3w:function c3w(d,e){this.a=d
this.b=e},
c3u:function c3u(d,e){this.a=d
this.b=e},
c3x:function c3x(d,e){this.a=d
this.b=e},
c3t:function c3t(d,e,f){this.a=d
this.b=e
this.c=f},
c3s:function c3s(d,e){this.a=d
this.b=e},
c3y:function c3y(d){this.a=d},
c3z:function c3z(d){this.a=d},
qJ:function qJ(d,e,f,g,h,i){var _=this
_.c=d
_.d=e
_.e=f
_.f=g
_.r=h
_.a=i},
avs:function avs(d,e){this.a=d
this.b=e},
avi:function avi(d,e){this.a=d
this.b=e},
avh:function avh(d){this.a=d},
avj:function avj(d,e,f){this.a=d
this.b=e
this.c=f},
avk:function avk(d,e){this.a=d
this.b=e},
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
avg:function avg(){},
avq:function avq(d,e){this.a=d
this.b=e},
avr:function avr(d,e){this.a=d
this.b=e},
cln(d,e){var x,w
if(d!=null){x=C.e.l(J.u(d))
if(x.length!==0)return x}if(e!=null){x=C.e.l(J.u(e))
w=x.length
if(w>8)return C.e.c_(x,w-8)
if(w!==0)return x}return"N/A"}},D,F,G,H
J=c[1]
A=c[0]
C=c[2]
E=c[40]
B=a.updateHolder(c[24],B)
D=c[62]
F=c[27]
G=c[35]
H=c[48]
B.qJ.prototype={
G4(d,e){var x=A.e5(e),w=y.X,v=A.kp(d,null,w),u=v==null?null:v.c.a
if((u==null?"":u)===x)return
F.ri(d,x,null,w,w)},
OO(d){return this.aYI(d)},
aYI(d){var x=0,w=A.l(y.H),v,u=2,t=[],s,r,q,p
var $async$OO=A.m(function(e,f){if(e===1){t.push(f)
x=u}for(;;)switch(x){case 0:q=C.e.l(d)
if(J.as(q)===0){x=1
break}u=4
x=7
return A.d(A.vF(A.zf(null,null,q,null,"mailto"),C.zk),$async$OO)
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
OP(d){return this.aYJ(d)},
aYJ(d){var x=0,w=A.l(y.H),v=1,u=[],t=this,s,r,q,p,o,n,m,l
var $async$OP=A.m(function(e,f){if(e===1){u.push(f)
x=v}for(;;)switch(x){case 0:o=C.e.l(t.c.go)
n=o.length!==0
m=n?o:C.e.l(d)
if(C.e.b6(m,"http://")||C.e.b6(m,"https://"))q=A.bx(m,0,null)
else q=A.bx(n?o:"https://www.facebook.com/3tavs",0,null)
s=q
v=3
x=6
return A.d(A.vF(s,C.o8),$async$OP)
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
alc(d,e,f){var x=null,w=A.aR(d,C.x,x,18),v=f==null,u=A.L(A.a([w,C.al,A.F(A.c(e,x,x,x,x,A.A(x,x,C.wS,x,!v?C.eQ:C.a8,C.br,x,x,x,x,x,12,x,x,x,x,x,!0,x,x,x,x,x,x,x,x),x,x,x),1)],y.p),C.E,C.k,C.q,0,x)
return v?u:A.cx(!1,x,!0,u,x,!0,x,x,x,x,x,x,x,x,x,x,f,x,x,x,x,x,x,x)},
a1y(d,e){return this.alc(d,e,null)},
D(d){var x=null
return A.Q(x,A.dQ(new B.avs(this,this.c)),C.v,C.nr,x,x,x,x,x,x,D.ag6,x,x,x)}}
var z=a.updateTypes(["m5(S)"])
B.c3E.prototype={
$1(d){var x=null
return A.cL(A.a([A.bt(C.bQ,x,x,x,new B.c3C(d),x,x),A.dg(D.bAZ,new B.c3D(d,this.a,this.b),x)],y.p),x,x,x,D.bDM,x,x,x,D.bEE,x)},
$S:10}
B.c3C.prototype={
$0(){A.R(this.a,!1).a2(null)
return null},
$S:0}
B.c3D.prototype={
$0(){var x=0,w=A.l(y.H),v=this
var $async$$0=A.m(function(d,e){if(d===1)return A.i(e,w)
for(;;)switch(x){case 0:A.R(v.a,!1).a2(null)
x=2
return A.d(A.bf(null,null,!0,null,new B.c3A(),v.b,null,!0,!0,y.z),$async$$0)
case 2:x=3
return A.d(v.c.$0(),$async$$0)
case 3:return A.j(null,w)}})
return A.k($async$$0,w)},
$S:1}
B.c3A.prototype={
$1(d){return G.qs},
$S:z+0}
B.c3F.prototype={
$1(d){return A.ax(d,y.N,y.z)},
$S:24}
B.c3G.prototype={
$1(d){var x,w=d.h(0,"status"),v=J.u(w==null?"":w).toLowerCase()
if(!J.n(v,"delivered"))return!1
x=d.h(0,"feedback_stars")
return x==null},
$S:17}
B.c3H.prototype={
$1(d){return new A.dU(new B.c3B(this.a,this.b,d),null)},
$S:19}
B.c3B.prototype={
$2(d,e){var x,w,v=null,u=this.a,t=u.b,s=A.c("Feedback \xb7 "+B.cln(t.h(0,"order_no"),t.h(0,"id")),v,v,v,v,v,v,v,v),r=y.p,q=A.a([],r),p=u.a
if(p.length>1){x=u.b
w=A.E(p).i("w<1,aw<U<e,@>>>")
p=A.v(new A.w(p,new B.c3v(),w),w.i("aa.E"))
C.f.t(q,A.a([A.ew(D.amC,v,v,v,!0,!1,p,v,new B.c3w(u,e),v,x,y.P),C.K],r))}q.push(D.bGv)
q.push(C.D)
q.push(A.L(A.hL(5,new B.c3x(u,e),!0,y.l),C.u,C.k,C.q,0,v))
q.push(C.D)
q.push(A.aE(v,C.O,!1,v,!0,C.w,v,A.aF(),this.b,v,v,v,v,v,2,D.anF,C.A,!0,v,!0,v,!1,v,C.a2,v,v,v,v,v,v,v,v,4,v,v,!1,"\u2022",v,v,v,v,v,!1,v,v,!1,v,!0,v,C.U,v,v,v,v,v,v,v,v,v,v,v,v,!0,C.L,v,C.S,v,v,v,v))
u=A.bs(A.x(q,C.E,C.k,C.a1,0,C.t),v,C.A,v,v,v,C.a0)
q=this.c
return A.cL(A.a([A.bt(C.bQ,v,v,v,new B.c3y(q),v,v),A.dg(C.pd,new B.c3z(q),v)],r),v,v,v,u,v,v,v,s,v)},
$S:48}
B.c3v.prototype={
$1(d){var x=null
return A.dV(A.c(B.cln(d.h(0,"order_no"),d.h(0,"id")),x,x,x,x,x,x,x,x),d,y.P)},
$S:1179}
B.c3w.prototype={
$1(d){if(d==null)return
this.b.$1(new B.c3u(this.a,d))},
$S:1180}
B.c3u.prototype={
$0(){return this.a.b=this.b},
$S:0}
B.c3x.prototype={
$1(d){var x=null,w=this.a,v=d<w.c,u=v?C.jf:C.nZ
return A.aQ(x,x,x,A.aR(u,v?C.mj:x,x,x),x,x,new B.c3t(w,this.b,d),x,20,x,x,C.dM)},
$S:151}
B.c3t.prototype={
$0(){return this.b.$1(new B.c3s(this.a,this.c))},
$S:0}
B.c3s.prototype={
$0(){return this.a.c=this.b+1},
$S:0}
B.c3y.prototype={
$0(){A.R(this.a,!1).a2(!1)
return null},
$S:0}
B.c3z.prototype={
$0(){A.R(this.a,!1).a2(!0)
return null},
$S:0}
B.avs.prototype={
$2(d,e){var x,w,v,u,t,s=null,r=e.b>900,q=r?s:220,p=this.b,o=y.p,n=A.a([A.bt(A.c(p.fr,s,s,s,s,D.bwK,s,s,s),s,s,s,new B.avi(d,p),s,s),A.kA(D.byq,C.L,p.y1)],o),m=this.a
if(m.d)n.push(A.hm(D.als,D.bFV,new B.avj(m,d,p),s))
q=A.ag(A.x(n,C.E,C.k,C.q,0,C.t),s,q)
n=A.x(A.a([A.bt(A.c("Gallery",s,s,s,s,D.mJ,s,s,s),s,s,s,new B.avk(m,d),s,s),A.bt(A.c("Catering Menu",s,s,s,s,D.mJ,s,s,s),s,s,s,new B.avl(m,d),s,s),A.bt(A.c("Restaurant",s,s,s,s,D.mJ,s,s,s),s,s,s,new B.avm(m,d),s,s)],o),C.E,C.k,C.q,0,C.t)
x=A.x(A.a([A.bt(A.c("Inquire Now",s,s,s,s,D.mJ,s,s,s),s,s,s,new B.avn(m,d),s,s),A.bt(A.c("Contact Us",s,s,s,s,D.mJ,s,s,s),s,s,s,new B.avo(m,d),s,s),A.bt(D.bIL,s,s,s,new B.avp(m,d),s,s)],o),C.E,C.k,C.q,0,C.t)
w=p.rx
v=A.aR(E.yJ,C.x,s,18)
w=A.cx(!1,s,!0,A.L(A.a([v,C.al,A.F(A.c(w,s,s,s,s,A.A(s,s,C.x,s,C.eQ,C.br,s,s,s,s,s,12,s,s,s,s,s,!0,s,s,s,s,s,s,s,s),s,s,s),1)],o),C.E,C.k,C.q,0,s),s,!0,s,s,s,s,s,s,s,s,s,s,new B.avq(m,p),s,s,s,s,s,s,s)
u=A.a([q,n,x,A.ag(w,s,200),A.x(A.a([m.a1y(E.yR,p.ry),m.a1y(E.yU,p.to)],o),C.E,C.k,C.q,0,C.t),A.x(A.a([m.a1y(E.r2,p.x1),m.alc(E.yI,p.x2,new B.avr(m,p))],o),C.E,C.k,C.q,0,C.t)],o)
if(r){q=A.a([],o)
for(t=0;t<6;++t){p=A.a([],o)
if(t>0)p.push(D.bqw)
p.push(new A.dO(1,C.c6,u[t],s))
C.f.t(q,p)}q.push(C.cF)
q.push(A.na("lib/assets/main-2.png",C.as,!1,C.c5,C.c_,72,s))
return A.L(q,C.E,C.k,C.q,0,s)}return A.ch(C.aT,u,C.aU,12,24)},
$S:1181}
B.avi.prototype={
$0(){var x=this.a,w=this.b,v=w.fr,u=w.fx
w=A.b5("\\[color=#0{3,8}\\]",!1,!1,!1)
u=A.bF(u,w,"")
w=A.b5("\\[color=#1[Ee]1[Ee]1[Ee]\\]",!1,!1,!1)
u=A.bF(u,w,"")
w=A.b5("\\[color=#262626\\]",!1,!1,!1)
u=A.bF(u,w,"")
w=A.b5("\\[color=black\\]",!1,!1,!1)
u=A.bF(u,w,"")
u=A.bF(u,"[/color]","")
w=A.b5("color\\s*:\\s*#0{3,8}\\s*;?",!1,!1,!1)
u=A.bF(u,w,"")
w=A.b5("color\\s*:\\s*black\\s*;?",!1,!1,!1)
w=A.kA(D.buz,C.L,A.bF(u,w,""))
A.eu(A.a([new A.dz("Close",null,new B.avh(x),!1,null)],y.p),!0,w,x,560,!0,v,y.H)},
$S:0}
B.avh.prototype={
$0(){A.R(this.a,!1).a2(null)
return null},
$S:0}
B.avj.prototype={
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
B.avk.prototype={
$0(){return this.a.G4(this.b,"/gallery")},
$S:0}
B.avl.prototype={
$0(){return this.a.G4(this.b,"/catering-menu")},
$S:0}
B.avm.prototype={
$0(){return this.a.G4(this.b,"/restaurant")},
$S:0}
B.avn.prototype={
$0(){return this.a.G4(this.b,"/inquire")},
$S:0}
B.avo.prototype={
$0(){return this.a.G4(this.b,"/contact-us")},
$S:0}
B.avp.prototype={
$0(){var x=this.a,w=x.f
if(w==null)w=new B.avg()
return B.Em(this.b,x.e,w)},
$S:0}
B.avg.prototype={
$0(){var x=0,w=A.l(y.H)
var $async$$0=A.m(function(d,e){if(d===1)return A.i(e,w)
for(;;)switch(x){case 0:return A.j(null,w)}})
return A.k($async$$0,w)},
$S:1}
B.avq.prototype={
$0(){return this.a.OP(this.b.rx)},
$S:0}
B.avr.prototype={
$0(){return this.a.OO(this.b.x2)},
$S:0};(function inheritance(){var x=a.inheritMany,w=a.inherit
x(A.ht,[B.c3E,B.c3A,B.c3F,B.c3G,B.c3H,B.c3v,B.c3w,B.c3x])
x(A.jG,[B.c3C,B.c3D,B.c3u,B.c3t,B.c3s,B.c3y,B.c3z,B.avi,B.avh,B.avj,B.avk,B.avl,B.avm,B.avn,B.avo,B.avp,B.avg,B.avq,B.avr])
x(A.kL,[B.c3B,B.avs])
w(B.qJ,A.ap)})()
A.kE(b.typeUniverse,JSON.parse('{"qJ":{"ap":[],"f":[]}}'))
var y=(function rtii(){var x=A.ak
return{p:x("G<f>"),P:x("U<e,@>"),f:x("U<@,@>"),K:x("a8"),N:x("e"),l:x("f"),q:x("t9"),y:x("O"),z:x("@"),g:x("Y<@>?"),X:x("a8?"),H:x("~")}})();(function constants(){D.ag6=new A.ac(40,20,40,20)
D.als=new A.aj(C.hP,14,C.br,null,null)
D.amC=new A.aV(null,null,null,"Order",null,null,null,null,null,null,null,null,null,null,null,null,!0,!0,!1,null,null,null,null,null,null,!0,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,!0,null,null,null,null)
D.anF=new A.aV(null,null,null,"Remarks",null,null,null,null,null,null,"Optional comments about your completed order",null,null,null,null,null,!0,!0,!1,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,!0,null,null,null,null)
D.bqw=new A.bk(28,null,null,null)
D.bBx=new A.o("Failed to submit feedback",null,null,null,null,null,null,null,null,null,null)
D.brp=new A.c2(D.bBx,null,null,null,null,null,null,null,null,null,null,null,null,C.aa,!1,null,null,null,C.w,null)
D.bGI=new A.o("Thank you for your feedback",null,null,null,null,null,null,null,null,null,null)
D.brJ=new A.c2(D.bGI,null,null,null,null,null,null,null,null,null,null,null,null,C.aa,!1,null,null,null,C.w,null)
D.bDT=new A.o("No delivered restaurant orders available for feedback",null,null,null,null,null,null,null,null,null,null)
D.brK=new A.c2(D.bDT,null,null,null,null,null,null,null,null,null,null,null,null,C.aa,!1,null,null,null,C.w,null)
D.bGM=new A.o("Please log in to submit feedback",null,null,null,null,null,null,null,null,null,null)
D.brL=new A.c2(D.bGM,null,null,null,null,null,null,null,null,null,null,null,null,C.aa,!1,null,null,null,C.w,null)
D.bHU=new A.o("Could not load your orders",null,null,null,null,null,null,null,null,null,null)
D.a1_=new A.c2(D.bHU,null,null,null,null,null,null,null,null,null,null,null,null,C.aa,!1,null,null,null,C.w,null)
D.abj=new A.P(1,0.12156862745098039,0.1607843137254902,0.21568627450980393,C.F)
D.buz=new A.M(!0,D.abj,null,null,null,null,14,null,null,null,null,null,1.55,null,null,null,null,null,null,null,null,null,null,null,null,null)
D.bwK=new A.M(!0,C.T,null,null,null,null,null,C.ab,null,null,null,null,null,null,null,null,null,C.eQ,C.T,null,null,null,null,null,null,null)
D.aat=new A.P(1,0.9098039215686274,0.9176470588235294,0.9294117647058824,C.F)
D.byq=new A.M(!0,D.aat,null,null,null,null,11,null,null,null,null,null,1.4,null,null,null,null,null,null,null,null,null,null,null,null,null)
D.mJ=new A.M(!0,C.wS,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null)
D.bAZ=new A.o("Log in",null,null,null,null,null,null,null,null,null,null)
D.bDM=new A.o("Please log in to share feedback on a completed order.",null,null,null,null,null,null,null,null,null,null)
D.bEE=new A.o("Feedback",null,null,null,null,null,null,null,null,null,null)
D.bFV=new A.o("Edit",null,H.a1B,null,null,null,null,null,null,null,null)
D.bGv=new A.o("How was this restaurant order?",null,null,null,null,null,null,null,null,null,null)
D.bIL=new A.o("Feedback",null,D.mJ,null,null,null,null,null,null,null,null)})()};
(a=>{a["nstIkAYwNft+PRJB6aat6Ys43gs="]=a.current})($__dart_deferred_initializers__);