((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,A,C,E,B={
Em(d,e,f){return B.cG9(d,e,f)},
cG9(a5,a6,a7){var x=0,w=A.l(y.H),v,u=2,t=[],s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,a0,a1,a2,a3,a4
var $async$Em=A.m(function(a9,b0){if(a9===1){t.push(b0)
x=u}for(;;)switch(x){case 0:a1={}
x=!a6?3:4
break
case 3:x=5
return A.d(A.bh(null,null,!0,null,new B.c3d(a5,a7),a5,null,!0,!0,y.z),$async$Em)
case 5:x=1
break
case 4:a4=A
x=6
return A.d(A.d2(),$async$Em)
case 6:s=a4.aK(b0.a.h(0,"customer_token"))
if(s==null||s.length===0){if(a5.e!=null)a5.R(y.q).f.aE(D.brz)
x=1
break}j=a1.a=C.cy
u=8
j=y.N
x=11
return A.d(A.fF(A.bx("https://curatering.up.railway.app/api/restaurant/orders",0,null),A.N(["Authorization","Bearer "+s,"Content-Type","application/json"],j,j)).cz(C.lB),$async$Em)
case 11:r=b0
if(r.b!==200){if(a5.e!=null)a5.R(y.q).f.aE(D.a0Y)
x=1
break}j=r
q=C.a6.bq(A.ci(A.ch(j.e)).b6(j.w),null)
i=y.g.a(J.t(q,"orders"))
p=i==null?C.bA:i
j=J.ej(p,y.f)
j=A.dh(j,new B.c3e(),j.$ti.i("r.E"),y.P)
h=A.y(j).i("T<r.E>")
g=A.v(new A.T(j,new B.c3f(),h),h.i("r.E"))
a1.a=g
j=g
u=2
x=10
break
case 8:u=7
a2=t.pop()
if(a5.e!=null)a5.R(y.q).f.aE(D.a0Y)
x=1
break
x=10
break
case 7:x=2
break
case 10:if(j.length===0){if(a5.e!=null)a5.R(y.q).f.aE(D.bry)
x=1
break}if(a5.e==null){x=1
break}a1.b=C.f.ga9(j)
a1.c=5
j=$.W()
e=new A.ae(C.a3,j)
x=12
return A.d(A.bh(null,null,!0,null,new B.c3g(a1,e),a5,null,!0,!0,y.y),$async$Em)
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
return A.d(A.et(j,C.a6.cn(A.N(["stars",a1.c,"remarks",o],h,y.K),null),null,a0),$async$Em)
case 17:m=b0
if(a5.e==null){x=1
break}if(m.b===200)a5.R(y.q).f.aE(D.brx)
else{l="Failed to submit feedback"
try{a1=m
k=C.a6.bq(A.ci(A.ch(a1.e)).b6(a1.w),null)
if(y.f.b(k)&&k.h(0,"error")!=null)l=J.u(k.h(0,"error"))}catch(a8){}a5.R(y.q).f.aE(A.cV(null,null,null,null,null,C.x,null,A.c(l,null,null,null,null,null,null,null,null),null,C.ab,null,null,null,null,null,null,null,null,null,null))}u=2
x=16
break
case 14:u=13
a3=t.pop()
if(a5.e!=null)a5.R(y.q).f.aE(D.bre)
x=16
break
case 13:x=2
break
case 16:case 1:return A.j(v,w)
case 2:return A.i(t.at(-1),w)}})
return A.k($async$Em,w)},
c3d:function c3d(d,e){this.a=d
this.b=e},
c3b:function c3b(d){this.a=d},
c3c:function c3c(d,e,f){this.a=d
this.b=e
this.c=f},
c39:function c39(){},
c3e:function c3e(){},
c3f:function c3f(){},
c3g:function c3g(d,e){this.a=d
this.b=e},
c3a:function c3a(d,e,f){this.a=d
this.b=e
this.c=f},
c34:function c34(){},
c35:function c35(d,e){this.a=d
this.b=e},
c33:function c33(d,e){this.a=d
this.b=e},
c36:function c36(d,e){this.a=d
this.b=e},
c32:function c32(d,e,f){this.a=d
this.b=e
this.c=f},
c31:function c31(d,e){this.a=d
this.b=e},
c37:function c37(d){this.a=d},
c38:function c38(d){this.a=d},
qK:function qK(d,e,f,g,h,i){var _=this
_.c=d
_.d=e
_.e=f
_.f=g
_.r=h
_.a=i},
avk:function avk(d,e){this.a=d
this.b=e},
ava:function ava(d,e){this.a=d
this.b=e},
av9:function av9(d){this.a=d},
avb:function avb(d,e,f){this.a=d
this.b=e
this.c=f},
avc:function avc(d,e){this.a=d
this.b=e},
avd:function avd(d,e){this.a=d
this.b=e},
ave:function ave(d,e){this.a=d
this.b=e},
avf:function avf(d,e){this.a=d
this.b=e},
avg:function avg(d,e){this.a=d
this.b=e},
avh:function avh(d,e){this.a=d
this.b=e},
av8:function av8(){},
avi:function avi(d,e){this.a=d
this.b=e},
avj:function avj(d,e){this.a=d
this.b=e},
ckU(d,e){var x,w
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
B.qK.prototype={
G2(d,e){var x=A.ec(e),w=y.X,v=A.kp(d,null,w),u=v==null?null:v.c.a
if((u==null?"":u)===x)return
F.rk(d,x,null,w,w)},
OM(d){return this.aYu(d)},
aYu(d){var x=0,w=A.l(y.H),v,u=2,t=[],s,r,q,p
var $async$OM=A.m(function(e,f){if(e===1){t.push(f)
x=u}for(;;)switch(x){case 0:q=C.e.l(d)
if(J.at(q)===0){x=1
break}u=4
x=7
return A.d(A.vE(A.ze(null,null,q,null,"mailto"),C.zj),$async$OM)
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
return A.k($async$OM,w)},
ON(d){return this.aYv(d)},
aYv(d){var x=0,w=A.l(y.H),v=1,u=[],t=this,s,r,q,p,o,n,m,l
var $async$ON=A.m(function(e,f){if(e===1){u.push(f)
x=v}for(;;)switch(x){case 0:o=C.e.l(t.c.go)
n=o.length!==0
m=n?o:C.e.l(d)
if(C.e.b8(m,"http://")||C.e.b8(m,"https://"))q=A.bx(m,0,null)
else q=A.bx(n?o:"https://www.facebook.com/3tavs",0,null)
s=q
v=3
x=6
return A.d(A.vE(s,C.o7),$async$ON)
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
return A.k($async$ON,w)},
al1(d,e,f){var x=null,w=A.aR(d,C.w,x,18),v=f==null,u=A.L(A.a([w,C.al,A.F(A.c(e,x,x,x,x,A.A(x,x,C.wQ,x,!v?C.eQ:C.a8,C.bq,x,x,x,x,x,12,x,x,x,x,x,!0,x,x,x,x,x,x,x,x),x,x,x),1)],y.p),C.E,C.k,C.q,0,x)
return v?u:A.cx(!1,x,!0,u,x,!0,x,x,x,x,x,x,x,x,x,x,f,x,x,x,x,x,x,x)},
a1v(d,e){return this.al1(d,e,null)},
D(d){var x=null
return A.Q(x,A.dO(new B.avk(this,this.c)),C.v,C.nq,x,x,x,x,x,x,D.ag_,x,x,x)}}
var z=a.updateTypes(["m4(S)"])
B.c3d.prototype={
$1(d){var x=null
return A.cL(A.a([A.bt(C.bQ,x,x,x,new B.c3b(d),x,x),A.dg(D.bAL,new B.c3c(d,this.a,this.b),x)],y.p),x,x,x,D.bDq,x,x,x,D.bEh,x)},
$S:10}
B.c3b.prototype={
$0(){A.R(this.a,!1).a2(null)
return null},
$S:0}
B.c3c.prototype={
$0(){var x=0,w=A.l(y.H),v=this
var $async$$0=A.m(function(d,e){if(d===1)return A.i(e,w)
for(;;)switch(x){case 0:A.R(v.a,!1).a2(null)
x=2
return A.d(A.bh(null,null,!0,null,new B.c39(),v.b,null,!0,!0,y.z),$async$$0)
case 2:x=3
return A.d(v.c.$0(),$async$$0)
case 3:return A.j(null,w)}})
return A.k($async$$0,w)},
$S:1}
B.c39.prototype={
$1(d){return G.qs},
$S:z+0}
B.c3e.prototype={
$1(d){return A.ax(d,y.N,y.z)},
$S:25}
B.c3f.prototype={
$1(d){var x,w=d.h(0,"status"),v=J.u(w==null?"":w).toLowerCase()
if(!J.n(v,"delivered"))return!1
x=d.h(0,"feedback_stars")
return x==null},
$S:17}
B.c3g.prototype={
$1(d){return new A.dU(new B.c3a(this.a,this.b,d),null)},
$S:19}
B.c3a.prototype={
$2(d,e){var x,w,v=null,u=this.a,t=u.b,s=A.c("Feedback \xb7 "+B.ckU(t.h(0,"order_no"),t.h(0,"id")),v,v,v,v,v,v,v,v),r=y.p,q=A.a([],r),p=u.a
if(p.length>1){x=u.b
w=A.E(p).i("w<1,ay<U<e,@>>>")
p=A.v(new A.w(p,new B.c34(),w),w.i("aa.E"))
C.f.t(q,A.a([A.ew(D.ams,v,v,v,!0,!1,p,v,new B.c35(u,e),v,x,y.P),C.K],r))}q.push(D.bG7)
q.push(C.D)
q.push(A.L(A.hL(5,new B.c36(u,e),!0,y.l),C.u,C.k,C.q,0,v))
q.push(C.D)
q.push(A.aE(v,C.N,!1,v,!0,C.x,v,A.aF(),this.b,v,v,v,v,v,2,D.anv,C.A,!0,v,!0,v,!1,v,C.a2,v,v,v,v,v,v,v,v,4,v,v,!1,"\u2022",v,v,v,v,v,!1,v,v,!1,v,!0,v,C.T,v,v,v,v,v,v,v,v,v,v,v,v,!0,C.L,v,C.S,v,v,v,v))
u=A.br(A.x(q,C.E,C.k,C.a1,0,C.t),v,C.A,v,v,v,C.a0)
q=this.c
return A.cL(A.a([A.bt(C.bQ,v,v,v,new B.c37(q),v,v),A.dg(C.pd,new B.c38(q),v)],r),v,v,v,u,v,v,v,s,v)},
$S:49}
B.c34.prototype={
$1(d){var x=null
return A.e_(A.c(B.ckU(d.h(0,"order_no"),d.h(0,"id")),x,x,x,x,x,x,x,x),d,y.P)},
$S:1175}
B.c35.prototype={
$1(d){if(d==null)return
this.b.$1(new B.c33(this.a,d))},
$S:1176}
B.c33.prototype={
$0(){return this.a.b=this.b},
$S:0}
B.c36.prototype={
$1(d){var x=null,w=this.a,v=d<w.c,u=v?C.jf:C.nY
return A.aQ(x,x,x,A.aR(u,v?C.mj:x,x,x),x,x,new B.c32(w,this.b,d),x,20,x,x,C.dL)},
$S:175}
B.c32.prototype={
$0(){return this.b.$1(new B.c31(this.a,this.c))},
$S:0}
B.c31.prototype={
$0(){return this.a.c=this.b+1},
$S:0}
B.c37.prototype={
$0(){A.R(this.a,!1).a2(!1)
return null},
$S:0}
B.c38.prototype={
$0(){A.R(this.a,!1).a2(!0)
return null},
$S:0}
B.avk.prototype={
$2(d,e){var x,w,v,u,t,s=null,r=e.b>900,q=r?s:220,p=this.b,o=y.p,n=A.a([A.bt(A.c(p.fr,s,s,s,s,D.bwv,s,s,s),s,s,s,new B.ava(d,p),s,s),A.kz(D.byb,C.L,p.y1)],o),m=this.a
if(m.d)n.push(A.hm(D.alj,D.bFy,new B.avb(m,d,p),s))
q=A.ag(A.x(n,C.E,C.k,C.q,0,C.t),s,q)
n=A.x(A.a([A.bt(A.c("Gallery",s,s,s,s,D.mI,s,s,s),s,s,s,new B.avc(m,d),s,s),A.bt(A.c("Catering Menu",s,s,s,s,D.mI,s,s,s),s,s,s,new B.avd(m,d),s,s),A.bt(A.c("Restaurant",s,s,s,s,D.mI,s,s,s),s,s,s,new B.ave(m,d),s,s)],o),C.E,C.k,C.q,0,C.t)
x=A.x(A.a([A.bt(A.c("Inquire Now",s,s,s,s,D.mI,s,s,s),s,s,s,new B.avf(m,d),s,s),A.bt(A.c("Contact Us",s,s,s,s,D.mI,s,s,s),s,s,s,new B.avg(m,d),s,s),A.bt(D.bIo,s,s,s,new B.avh(m,d),s,s)],o),C.E,C.k,C.q,0,C.t)
w=p.rx
v=A.aR(E.yI,C.w,s,18)
w=A.cx(!1,s,!0,A.L(A.a([v,C.al,A.F(A.c(w,s,s,s,s,A.A(s,s,C.w,s,C.eQ,C.bq,s,s,s,s,s,12,s,s,s,s,s,!0,s,s,s,s,s,s,s,s),s,s,s),1)],o),C.E,C.k,C.q,0,s),s,!0,s,s,s,s,s,s,s,s,s,s,new B.avi(m,p),s,s,s,s,s,s,s)
u=A.a([q,n,x,A.ag(w,s,200),A.x(A.a([m.a1v(E.yQ,p.ry),m.a1v(E.yT,p.to)],o),C.E,C.k,C.q,0,C.t),A.x(A.a([m.a1v(E.r1,p.x1),m.al1(E.yH,p.x2,new B.avj(m,p))],o),C.E,C.k,C.q,0,C.t)],o)
if(r){q=A.a([],o)
for(t=0;t<6;++t){p=A.a([],o)
if(t>0)p.push(D.bql)
p.push(new A.dR(1,C.c8,u[t],s))
C.f.t(q,p)}q.push(C.cE)
q.push(A.n9("lib/assets/main-2.png",C.as,!1,C.dn,C.c4,72,s))
return A.L(q,C.E,C.k,C.q,0,s)}return A.cr(C.aT,u,C.aW,12,24)},
$S:1177}
B.ava.prototype={
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
w=A.kz(D.buk,C.L,A.bE(u,w,""))
A.eu(A.a([new A.dy("Close",null,new B.av9(x),!1,null)],y.p),!0,w,x,560,!0,v,y.H)},
$S:0}
B.av9.prototype={
$0(){A.R(this.a,!1).a2(null)
return null},
$S:0}
B.avb.prototype={
$0(){var x=0,w=A.l(y.H),v,u=this,t,s
var $async$$0=A.m(function(d,e){if(d===1)return A.i(e,w)
for(;;)switch(x){case 0:t=u.c
x=3
return A.d(A.tj(u.b,t.y1,"Edit footer copyright"),$async$$0)
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
B.avc.prototype={
$0(){return this.a.G2(this.b,"/gallery")},
$S:0}
B.avd.prototype={
$0(){return this.a.G2(this.b,"/catering-menu")},
$S:0}
B.ave.prototype={
$0(){return this.a.G2(this.b,"/restaurant")},
$S:0}
B.avf.prototype={
$0(){return this.a.G2(this.b,"/inquire")},
$S:0}
B.avg.prototype={
$0(){return this.a.G2(this.b,"/contact-us")},
$S:0}
B.avh.prototype={
$0(){var x=this.a,w=x.f
if(w==null)w=new B.av8()
return B.Em(this.b,x.e,w)},
$S:0}
B.av8.prototype={
$0(){var x=0,w=A.l(y.H)
var $async$$0=A.m(function(d,e){if(d===1)return A.i(e,w)
for(;;)switch(x){case 0:return A.j(null,w)}})
return A.k($async$$0,w)},
$S:1}
B.avi.prototype={
$0(){return this.a.ON(this.b.rx)},
$S:0}
B.avj.prototype={
$0(){return this.a.OM(this.b.x2)},
$S:0};(function inheritance(){var x=a.inheritMany,w=a.inherit
x(A.ht,[B.c3d,B.c39,B.c3e,B.c3f,B.c3g,B.c34,B.c35,B.c36])
x(A.jD,[B.c3b,B.c3c,B.c33,B.c32,B.c31,B.c37,B.c38,B.ava,B.av9,B.avb,B.avc,B.avd,B.ave,B.avf,B.avg,B.avh,B.av8,B.avi,B.avj])
x(A.kK,[B.c3a,B.avk])
w(B.qK,A.aq)})()
A.kD(b.typeUniverse,JSON.parse('{"qK":{"aq":[],"f":[]}}'))
var y=(function rtii(){var x=A.aj
return{p:x("G<f>"),P:x("U<e,@>"),f:x("U<@,@>"),K:x("a8"),N:x("e"),l:x("f"),q:x("tb"),y:x("O"),z:x("@"),g:x("Y<@>?"),X:x("a8?"),H:x("~")}})();(function constants(){D.ag_=new A.ac(40,20,40,20)
D.alj=new A.ak(C.hO,14,C.bq,null,null)
D.ams=new A.aV(null,null,null,"Order",null,null,null,null,null,null,null,null,null,null,null,null,!0,!0,!1,null,null,null,null,null,null,!0,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,!0,null,null,null,null)
D.anv=new A.aV(null,null,null,"Remarks",null,null,null,null,null,null,"Optional comments about your completed order",null,null,null,null,null,!0,!0,!1,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,!0,null,null,null,null)
D.bql=new A.bk(28,null,null,null)
D.bBi=new A.o("Failed to submit feedback",null,null,null,null,null,null,null,null,null,null)
D.bre=new A.ca(D.bBi,null,null,null,null,null,null,null,null,null,null,null,null,C.ab,!1,null,null,null,C.x,null)
D.bGk=new A.o("Thank you for your feedback",null,null,null,null,null,null,null,null,null,null)
D.brx=new A.ca(D.bGk,null,null,null,null,null,null,null,null,null,null,null,null,C.ab,!1,null,null,null,C.x,null)
D.bDx=new A.o("No delivered restaurant orders available for feedback",null,null,null,null,null,null,null,null,null,null)
D.bry=new A.ca(D.bDx,null,null,null,null,null,null,null,null,null,null,null,null,C.ab,!1,null,null,null,C.x,null)
D.bGo=new A.o("Please log in to submit feedback",null,null,null,null,null,null,null,null,null,null)
D.brz=new A.ca(D.bGo,null,null,null,null,null,null,null,null,null,null,null,null,C.ab,!1,null,null,null,C.x,null)
D.bHw=new A.o("Could not load your orders",null,null,null,null,null,null,null,null,null,null)
D.a0Y=new A.ca(D.bHw,null,null,null,null,null,null,null,null,null,null,null,null,C.ab,!1,null,null,null,C.x,null)
D.abe=new A.P(1,0.12156862745098039,0.1607843137254902,0.21568627450980393,C.F)
D.buk=new A.M(!0,D.abe,null,null,null,null,14,null,null,null,null,null,1.55,null,null,null,null,null,null,null,null,null,null,null,null,null)
D.bwv=new A.M(!0,C.U,null,null,null,null,null,C.aa,null,null,null,null,null,null,null,null,null,C.eQ,C.U,null,null,null,null,null,null,null)
D.aao=new A.P(1,0.9098039215686274,0.9176470588235294,0.9294117647058824,C.F)
D.byb=new A.M(!0,D.aao,null,null,null,null,11,null,null,null,null,null,1.4,null,null,null,null,null,null,null,null,null,null,null,null,null)
D.mI=new A.M(!0,C.wQ,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null)
D.bAL=new A.o("Log in",null,null,null,null,null,null,null,null,null,null)
D.bDq=new A.o("Please log in to share feedback on a completed order.",null,null,null,null,null,null,null,null,null,null)
D.bEh=new A.o("Feedback",null,null,null,null,null,null,null,null,null,null)
D.bFy=new A.o("Edit",null,H.a1z,null,null,null,null,null,null,null,null)
D.bG7=new A.o("How was this restaurant order?",null,null,null,null,null,null,null,null,null,null)
D.bIo=new A.o("Feedback",null,D.mI,null,null,null,null,null,null,null,null)})()};
(a=>{a["SUVDfnLbQzC3SCpeNi/9xpnfwAc="]=a.current})($__dart_deferred_initializers__);