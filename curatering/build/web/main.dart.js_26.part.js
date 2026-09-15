((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,A,C,E,B={
Em(d,e,f){return B.cG9(d,e,f)},
cG9(a5,a6,a7){var x=0,w=A.l(y.H),v,u=2,t=[],s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,a0,a1,a2,a3,a4
var $async$Em=A.m(function(a9,b0){if(a9===1){t.push(b0)
x=u}for(;;)switch(x){case 0:a1={}
x=!a6?3:4
break
case 3:x=5
return A.d(A.bi(null,null,!0,null,new B.c3c(a5,a7),a5,null,!0,!0,y.z),$async$Em)
case 5:x=1
break
case 4:a4=A
x=6
return A.d(A.d2(),$async$Em)
case 6:s=a4.aK(b0.a.h(0,"customer_token"))
if(s==null||s.length===0){if(a5.e!=null)a5.S(y.q).f.aE(D.brJ)
x=1
break}j=a1.a=C.cy
u=8
j=y.N
x=11
return A.d(A.fF(A.bx("https://curatering.up.railway.app/api/restaurant/orders",0,null),A.N(["Authorization","Bearer "+s,"Content-Type","application/json"],j,j)).cz(C.lB),$async$Em)
case 11:r=b0
if(r.b!==200){if(a5.e!=null)a5.S(y.q).f.aE(D.a15)
x=1
break}j=r
q=C.a6.bq(A.ch(A.cg(j.e)).b6(j.w),null)
i=y.g.a(J.t(q,"orders"))
p=i==null?C.bA:i
j=J.ej(p,y.f)
j=A.di(j,new B.c3d(),j.$ti.i("r.E"),y.P)
h=A.y(j).i("T<r.E>")
g=A.v(new A.T(j,new B.c3e(),h),h.i("r.E"))
a1.a=g
j=g
u=2
x=10
break
case 8:u=7
a2=t.pop()
if(a5.e!=null)a5.S(y.q).f.aE(D.a15)
x=1
break
x=10
break
case 7:x=2
break
case 10:if(j.length===0){if(a5.e!=null)a5.S(y.q).f.aE(D.brI)
x=1
break}if(a5.e==null){x=1
break}a1.b=C.f.ga9(j)
a1.c=5
j=$.W()
e=new A.ae(C.a3,j)
x=12
return A.d(A.bi(null,null,!0,null,new B.c3f(a1,e),a5,null,!0,!0,y.y),$async$Em)
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
break}if(m.b===200)a5.S(y.q).f.aE(D.brH)
else{l="Failed to submit feedback"
try{a1=m
k=C.a6.bq(A.ch(A.cg(a1.e)).b6(a1.w),null)
if(y.f.b(k)&&k.h(0,"error")!=null)l=J.u(k.h(0,"error"))}catch(a8){}a5.S(y.q).f.aE(A.cV(null,null,null,null,null,C.x,null,A.c(l,null,null,null,null,null,null,null,null),null,C.ab,null,null,null,null,null,null,null,null,null,null))}u=2
x=16
break
case 14:u=13
a3=t.pop()
if(a5.e!=null)a5.S(y.q).f.aE(D.bro)
x=16
break
case 13:x=2
break
case 16:case 1:return A.j(v,w)
case 2:return A.i(t.at(-1),w)}})
return A.k($async$Em,w)},
c3c:function c3c(d,e){this.a=d
this.b=e},
c3a:function c3a(d){this.a=d},
c3b:function c3b(d,e,f){this.a=d
this.b=e
this.c=f},
c38:function c38(){},
c3d:function c3d(){},
c3e:function c3e(){},
c3f:function c3f(d,e){this.a=d
this.b=e},
c39:function c39(d,e,f){this.a=d
this.b=e
this.c=f},
c33:function c33(){},
c34:function c34(d,e){this.a=d
this.b=e},
c32:function c32(d,e){this.a=d
this.b=e},
c35:function c35(d,e){this.a=d
this.b=e},
c31:function c31(d,e,f){this.a=d
this.b=e
this.c=f},
c30:function c30(d,e){this.a=d
this.b=e},
c36:function c36(d){this.a=d},
c37:function c37(d){this.a=d},
qL:function qL(d,e,f,g,h,i){var _=this
_.c=d
_.d=e
_.e=f
_.f=g
_.r=h
_.a=i},
avr:function avr(d,e){this.a=d
this.b=e},
avh:function avh(d,e){this.a=d
this.b=e},
avg:function avg(d){this.a=d},
avi:function avi(d,e,f){this.a=d
this.b=e
this.c=f},
avj:function avj(d,e){this.a=d
this.b=e},
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
avf:function avf(){},
avp:function avp(d,e){this.a=d
this.b=e},
avq:function avq(d,e){this.a=d
this.b=e},
ckT(d,e){var x,w
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
D=c[62]
F=c[27]
G=c[35]
H=c[48]
B.qL.prototype={
G_(d,e){var x=A.ec(e),w=y.X,v=A.kq(d,null,w),u=v==null?null:v.c.a
if((u==null?"":u)===x)return
F.rl(d,x,null,w,w)},
OK(d){return this.aYu(d)},
aYu(d){var x=0,w=A.l(y.H),v,u=2,t=[],s,r,q,p
var $async$OK=A.m(function(e,f){if(e===1){t.push(f)
x=u}for(;;)switch(x){case 0:q=C.e.l(d)
if(J.at(q)===0){x=1
break}u=4
x=7
return A.d(A.vD(A.zc(null,null,q,null,"mailto"),C.zl),$async$OK)
case 7:u=2
x=6
break
case 4:u=3
p=t.pop()
s=A.a4(p)
A.en().$1("Failed to open mailto: "+A.h(s))
x=6
break
case 3:x=2
break
case 6:case 1:return A.j(v,w)
case 2:return A.i(t.at(-1),w)}})
return A.k($async$OK,w)},
OL(d){return this.aYv(d)},
aYv(d){var x=0,w=A.l(y.H),v=1,u=[],t=this,s,r,q,p,o,n,m,l
var $async$OL=A.m(function(e,f){if(e===1){u.push(f)
x=v}for(;;)switch(x){case 0:o=C.e.l(t.c.go)
n=o.length!==0
m=n?o:C.e.l(d)
if(C.e.b8(m,"http://")||C.e.b8(m,"https://"))q=A.bx(m,0,null)
else q=A.bx(n?o:"https://www.facebook.com/3tavs",0,null)
s=q
v=3
x=6
return A.d(A.vD(s,C.o8),$async$OL)
case 6:v=1
x=5
break
case 3:v=2
l=u.pop()
r=A.a4(l)
A.en().$1("Failed to open Facebook: "+A.h(r))
x=5
break
case 2:x=1
break
case 5:return A.j(null,w)
case 1:return A.i(u.at(-1),w)}})
return A.k($async$OL,w)},
al_(d,e,f){var x=null,w=A.aS(d,C.w,x,18),v=f==null,u=A.L(A.a([w,C.al,A.F(A.c(e,x,x,x,x,A.A(x,x,C.wR,x,!v?C.eS:C.a8,C.bs,x,x,x,x,x,12,x,x,x,x,x,!0,x,x,x,x,x,x,x,x),x,x,x),1)],y.p),C.E,C.k,C.q,0,x)
return v?u:A.cx(!1,x,!0,u,x,!0,x,x,x,x,x,x,x,x,x,x,f,x,x,x,x,x,x,x)},
a1r(d,e){return this.al_(d,e,null)},
D(d){var x=null
return A.P(x,A.dO(new B.avr(this,this.c)),C.v,C.nr,x,x,x,x,x,x,D.ag4,x,x,x)}}
var z=a.updateTypes(["m4(S)"])
B.c3c.prototype={
$1(d){var x=null
return A.cL(A.a([A.bt(C.bQ,x,x,x,new B.c3a(d),x,x),A.dg(D.bAY,new B.c3b(d,this.a,this.b),x)],y.p),x,x,x,D.bDG,x,x,x,D.bEx,x)},
$S:10}
B.c3a.prototype={
$0(){A.R(this.a,!1).a2(null)
return null},
$S:0}
B.c3b.prototype={
$0(){var x=0,w=A.l(y.H),v=this
var $async$$0=A.m(function(d,e){if(d===1)return A.i(e,w)
for(;;)switch(x){case 0:A.R(v.a,!1).a2(null)
x=2
return A.d(A.bi(null,null,!0,null,new B.c38(),v.b,null,!0,!0,y.z),$async$$0)
case 2:x=3
return A.d(v.c.$0(),$async$$0)
case 3:return A.j(null,w)}})
return A.k($async$$0,w)},
$S:1}
B.c38.prototype={
$1(d){return G.qt},
$S:z+0}
B.c3d.prototype={
$1(d){return A.ax(d,y.N,y.z)},
$S:24}
B.c3e.prototype={
$1(d){var x,w=d.h(0,"status"),v=J.u(w==null?"":w).toLowerCase()
if(!J.n(v,"delivered"))return!1
x=d.h(0,"feedback_stars")
return x==null},
$S:17}
B.c3f.prototype={
$1(d){return new A.dU(new B.c39(this.a,this.b,d),null)},
$S:19}
B.c39.prototype={
$2(d,e){var x,w,v=null,u=this.a,t=u.b,s=A.c("Feedback \xb7 "+B.ckT(t.h(0,"order_no"),t.h(0,"id")),v,v,v,v,v,v,v,v),r=y.p,q=A.a([],r),p=u.a
if(p.length>1){x=u.b
w=A.E(p).i("w<1,ay<V<e,@>>>")
p=A.v(new A.w(p,new B.c33(),w),w.i("aa.E"))
C.f.t(q,A.a([A.ew(D.amw,v,v,v,!0,!1,p,v,new B.c34(u,e),v,x,y.P),C.K],r))}q.push(D.bGp)
q.push(C.D)
q.push(A.L(A.hN(5,new B.c35(u,e),!0,y.l),C.u,C.k,C.q,0,v))
q.push(C.D)
q.push(A.aE(v,C.N,!1,v,!0,C.x,v,A.aF(),this.b,v,v,v,v,v,2,D.anz,C.A,!0,v,!0,v,!1,v,C.a2,v,v,v,v,v,v,v,v,4,v,v,!1,"\u2022",v,v,v,v,v,!1,v,v,!1,v,!0,v,C.U,v,v,v,v,v,v,v,v,v,v,v,v,!0,C.L,v,C.S,v,v,v,v))
u=A.br(A.x(q,C.E,C.k,C.a1,0,C.t),v,C.A,v,v,v,C.a0)
q=this.c
return A.cL(A.a([A.bt(C.bQ,v,v,v,new B.c36(q),v,v),A.dg(C.pe,new B.c37(q),v)],r),v,v,v,u,v,v,v,s,v)},
$S:49}
B.c33.prototype={
$1(d){var x=null
return A.e_(A.c(B.ckT(d.h(0,"order_no"),d.h(0,"id")),x,x,x,x,x,x,x,x),d,y.P)},
$S:1175}
B.c34.prototype={
$1(d){if(d==null)return
this.b.$1(new B.c32(this.a,d))},
$S:1176}
B.c32.prototype={
$0(){return this.a.b=this.b},
$S:0}
B.c35.prototype={
$1(d){var x=null,w=this.a,v=d<w.c,u=v?C.jf:C.nZ
return A.aQ(x,x,x,A.aS(u,v?C.mj:x,x,x),x,x,new B.c31(w,this.b,d),x,20,x,x,C.dL)},
$S:175}
B.c31.prototype={
$0(){return this.b.$1(new B.c30(this.a,this.c))},
$S:0}
B.c30.prototype={
$0(){return this.a.c=this.b+1},
$S:0}
B.c36.prototype={
$0(){A.R(this.a,!1).a2(!1)
return null},
$S:0}
B.c37.prototype={
$0(){A.R(this.a,!1).a2(!0)
return null},
$S:0}
B.avr.prototype={
$2(d,e){var x,w,v,u,t,s=null,r=e.b>900,q=r?s:220,p=this.b,o=y.p,n=A.a([A.bt(A.c(p.fr,s,s,s,s,D.bwG,s,s,s),s,s,s,new B.avh(d,p),s,s),A.kA(D.bym,C.L,p.y1)],o),m=this.a
if(m.d)n.push(A.hm(D.aln,D.bFP,new B.avi(m,d,p),s))
q=A.ag(A.x(n,C.E,C.k,C.q,0,C.t),s,q)
n=A.x(A.a([A.bt(A.c("Gallery",s,s,s,s,D.mJ,s,s,s),s,s,s,new B.avj(m,d),s,s),A.bt(A.c("Catering Menu",s,s,s,s,D.mJ,s,s,s),s,s,s,new B.avk(m,d),s,s),A.bt(A.c("Restaurant",s,s,s,s,D.mJ,s,s,s),s,s,s,new B.avl(m,d),s,s)],o),C.E,C.k,C.q,0,C.t)
x=A.x(A.a([A.bt(A.c("Inquire Now",s,s,s,s,D.mJ,s,s,s),s,s,s,new B.avm(m,d),s,s),A.bt(A.c("Contact Us",s,s,s,s,D.mJ,s,s,s),s,s,s,new B.avn(m,d),s,s),A.bt(D.bIH,s,s,s,new B.avo(m,d),s,s)],o),C.E,C.k,C.q,0,C.t)
w=p.rx
v=A.aS(E.yK,C.w,s,18)
w=A.cx(!1,s,!0,A.L(A.a([v,C.al,A.F(A.c(w,s,s,s,s,A.A(s,s,C.w,s,C.eS,C.bs,s,s,s,s,s,12,s,s,s,s,s,!0,s,s,s,s,s,s,s,s),s,s,s),1)],o),C.E,C.k,C.q,0,s),s,!0,s,s,s,s,s,s,s,s,s,s,new B.avp(m,p),s,s,s,s,s,s,s)
u=A.a([q,n,x,A.ag(w,s,200),A.x(A.a([m.a1r(E.yS,p.ry),m.a1r(E.yV,p.to)],o),C.E,C.k,C.q,0,C.t),A.x(A.a([m.a1r(E.r2,p.x1),m.al_(E.yJ,p.x2,new B.avq(m,p))],o),C.E,C.k,C.q,0,C.t)],o)
if(r){q=A.a([],o)
for(t=0;t<6;++t){p=A.a([],o)
if(t>0)p.push(D.bqA)
p.push(new A.dR(1,C.c8,u[t],s))
C.f.t(q,p)}q.push(C.cE)
q.push(A.o5("lib/assets/main-2.png",C.au,C.du,C.c7,72,s))
return A.L(q,C.E,C.k,C.q,0,s)}return A.cq(C.aU,u,C.aX,12,24)},
$S:1177}
B.avh.prototype={
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
w=A.kA(D.buv,C.L,A.bL(u,w,""))
A.eu(A.a([new A.dy("Close",null,new B.avg(x),!1,null)],y.p),!0,w,x,560,!0,v,y.H)},
$S:0}
B.avg.prototype={
$0(){A.R(this.a,!1).a2(null)
return null},
$S:0}
B.avi.prototype={
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
B.avj.prototype={
$0(){return this.a.G_(this.b,"/gallery")},
$S:0}
B.avk.prototype={
$0(){return this.a.G_(this.b,"/catering-menu")},
$S:0}
B.avl.prototype={
$0(){return this.a.G_(this.b,"/restaurant")},
$S:0}
B.avm.prototype={
$0(){return this.a.G_(this.b,"/inquire")},
$S:0}
B.avn.prototype={
$0(){return this.a.G_(this.b,"/contact-us")},
$S:0}
B.avo.prototype={
$0(){var x=this.a,w=x.f
if(w==null)w=new B.avf()
return B.Em(this.b,x.e,w)},
$S:0}
B.avf.prototype={
$0(){var x=0,w=A.l(y.H)
var $async$$0=A.m(function(d,e){if(d===1)return A.i(e,w)
for(;;)switch(x){case 0:return A.j(null,w)}})
return A.k($async$$0,w)},
$S:1}
B.avp.prototype={
$0(){return this.a.OL(this.b.rx)},
$S:0}
B.avq.prototype={
$0(){return this.a.OK(this.b.x2)},
$S:0};(function inheritance(){var x=a.inheritMany,w=a.inherit
x(A.ht,[B.c3c,B.c38,B.c3d,B.c3e,B.c3f,B.c33,B.c34,B.c35])
x(A.jD,[B.c3a,B.c3b,B.c32,B.c31,B.c30,B.c36,B.c37,B.avh,B.avg,B.avi,B.avj,B.avk,B.avl,B.avm,B.avn,B.avo,B.avf,B.avp,B.avq])
x(A.kL,[B.c39,B.avr])
w(B.qL,A.aq)})()
A.kE(b.typeUniverse,JSON.parse('{"qL":{"aq":[],"f":[]}}'))
var y=(function rtii(){var x=A.ak
return{p:x("G<f>"),P:x("V<e,@>"),f:x("V<@,@>"),K:x("a8"),N:x("e"),l:x("f"),q:x("tb"),y:x("O"),z:x("@"),g:x("Z<@>?"),X:x("a8?"),H:x("~")}})();(function constants(){D.ag4=new A.ac(40,20,40,20)
D.aln=new A.aj(C.hO,14,C.bs,null,null)
D.amw=new A.aV(null,null,null,"Order",null,null,null,null,null,null,null,null,null,null,null,null,!0,!0,!1,null,null,null,null,null,null,!0,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,!0,null,null,null,null)
D.anz=new A.aV(null,null,null,"Remarks",null,null,null,null,null,null,"Optional comments about your completed order",null,null,null,null,null,!0,!0,!1,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,!0,null,null,null,null)
D.bqA=new A.bo(28,null,null,null)
D.bBv=new A.o("Failed to submit feedback",null,null,null,null,null,null,null,null,null,null)
D.bro=new A.c9(D.bBv,null,null,null,null,null,null,null,null,null,null,null,null,C.ab,!1,null,null,null,C.x,null)
D.bGC=new A.o("Thank you for your feedback",null,null,null,null,null,null,null,null,null,null)
D.brH=new A.c9(D.bGC,null,null,null,null,null,null,null,null,null,null,null,null,C.ab,!1,null,null,null,C.x,null)
D.bDN=new A.o("No delivered restaurant orders available for feedback",null,null,null,null,null,null,null,null,null,null)
D.brI=new A.c9(D.bDN,null,null,null,null,null,null,null,null,null,null,null,null,C.ab,!1,null,null,null,C.x,null)
D.bGG=new A.o("Please log in to submit feedback",null,null,null,null,null,null,null,null,null,null)
D.brJ=new A.c9(D.bGG,null,null,null,null,null,null,null,null,null,null,null,null,C.ab,!1,null,null,null,C.x,null)
D.bHP=new A.o("Could not load your orders",null,null,null,null,null,null,null,null,null,null)
D.a15=new A.c9(D.bHP,null,null,null,null,null,null,null,null,null,null,null,null,C.ab,!1,null,null,null,C.x,null)
D.abj=new A.Q(1,0.12156862745098039,0.1607843137254902,0.21568627450980393,C.F)
D.buv=new A.M(!0,D.abj,null,null,null,null,14,null,null,null,null,null,1.55,null,null,null,null,null,null,null,null,null,null,null,null,null)
D.bwG=new A.M(!0,C.T,null,null,null,null,null,C.aa,null,null,null,null,null,null,null,null,null,C.eS,C.T,null,null,null,null,null,null,null)
D.aat=new A.Q(1,0.9098039215686274,0.9176470588235294,0.9294117647058824,C.F)
D.bym=new A.M(!0,D.aat,null,null,null,null,11,null,null,null,null,null,1.4,null,null,null,null,null,null,null,null,null,null,null,null,null)
D.mJ=new A.M(!0,C.wR,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null)
D.bAY=new A.o("Log in",null,null,null,null,null,null,null,null,null,null)
D.bDG=new A.o("Please log in to share feedback on a completed order.",null,null,null,null,null,null,null,null,null,null)
D.bEx=new A.o("Feedback",null,null,null,null,null,null,null,null,null,null)
D.bFP=new A.o("Edit",null,H.a1H,null,null,null,null,null,null,null,null)
D.bGp=new A.o("How was this restaurant order?",null,null,null,null,null,null,null,null,null,null)
D.bIH=new A.o("Feedback",null,D.mJ,null,null,null,null,null,null,null,null)})()};
(a=>{a["P8+3ONyIBVcCxLpKL9Z51d1vyQE="]=a.current})($__dart_deferred_initializers__);