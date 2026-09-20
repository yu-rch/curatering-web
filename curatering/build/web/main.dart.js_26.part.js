((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,A,C,E,B={
Em(d,e,f){return B.cGT(d,e,f)},
cGT(a5,a6,a7){var x=0,w=A.l(y.H),v,u=2,t=[],s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,a0,a1,a2,a3,a4
var $async$Em=A.m(function(a9,b0){if(a9===1){t.push(b0)
x=u}for(;;)switch(x){case 0:a1={}
x=!a6?3:4
break
case 3:x=5
return A.d(A.bf(null,null,!0,null,new B.c3U(a5,a7),a5,null,!0,!0,y.z),$async$Em)
case 5:x=1
break
case 4:a4=A
x=6
return A.d(A.d2(),$async$Em)
case 6:s=a4.aK(b0.a.h(0,"customer_token"))
if(s==null||s.length===0){if(a5.e!=null)a5.R(y.q).f.aA(D.brV)
x=1
break}j=a1.a=C.cz
u=8
j=y.N
x=11
return A.d(A.fH(A.bx("https://curatering.up.railway.app/api/restaurant/orders",0,null),A.N(["Authorization","Bearer "+s,"Content-Type","application/json"],j,j)).cA(C.lE),$async$Em)
case 11:r=b0
if(r.b!==200){if(a5.e!=null)a5.R(y.q).f.aA(D.a10)
x=1
break}j=r
q=C.a6.bq(A.cj(A.ci(j.e)).b7(j.w),null)
i=y.g.a(J.t(q,"orders"))
p=i==null?C.br:i
j=J.ej(p,y.f)
j=A.dh(j,new B.c3V(),j.$ti.i("q.E"),y.P)
h=A.y(j).i("T<q.E>")
g=A.v(new A.T(j,new B.c3W(),h),h.i("q.E"))
a1.a=g
j=g
u=2
x=10
break
case 8:u=7
a2=t.pop()
if(a5.e!=null)a5.R(y.q).f.aA(D.a10)
x=1
break
x=10
break
case 7:x=2
break
case 10:if(j.length===0){if(a5.e!=null)a5.R(y.q).f.aA(D.brU)
x=1
break}if(a5.e==null){x=1
break}a1.b=C.f.ga8(j)
a1.c=5
j=$.W()
e=new A.ae(C.a3,j)
x=12
return A.d(A.bf(null,null,!0,null,new B.c3X(a1,e),a5,null,!0,!0,y.y),$async$Em)
case 12:d=b0
o=C.e.l(e.a.a)
e.K$=j
e.J$=0
if(d!==!0||a5.e==null){x=1
break}j=a1.b.h(0,"id")
n=J.u(j==null?a1.b.h(0,"order_no"):j)
u=14
j=A.bx("https://curatering.up.railway.app/api/restaurant/orders/"+A.h(n)+"/feedback",0,null)
h=y.N
a0=A.N(["Authorization","Bearer "+s,"Content-Type","application/json"],h,h)
x=17
return A.d(A.et(j,C.a6.cp(A.N(["stars",a1.c,"remarks",o],h,y.K),null),null,a0),$async$Em)
case 17:m=b0
if(a5.e==null){x=1
break}if(m.b===200)a5.R(y.q).f.aA(D.brT)
else{l="Failed to submit feedback"
try{a1=m
k=C.a6.bq(A.cj(A.ci(a1.e)).b7(a1.w),null)
if(y.f.b(k)&&k.h(0,"error")!=null)l=J.u(k.h(0,"error"))}catch(a8){}a5.R(y.q).f.aA(A.cR(null,null,null,null,null,C.w,null,A.c(l,null,null,null,null,null,null,null,null),null,C.ab,null,null,null,null,null,null,null,null,null,null))}u=2
x=16
break
case 14:u=13
a3=t.pop()
if(a5.e!=null)a5.R(y.q).f.aA(D.brz)
x=16
break
case 13:x=2
break
case 16:case 1:return A.j(v,w)
case 2:return A.i(t.at(-1),w)}})
return A.k($async$Em,w)},
c3U:function c3U(d,e){this.a=d
this.b=e},
c3S:function c3S(d){this.a=d},
c3T:function c3T(d,e,f){this.a=d
this.b=e
this.c=f},
c3Q:function c3Q(){},
c3V:function c3V(){},
c3W:function c3W(){},
c3X:function c3X(d,e){this.a=d
this.b=e},
c3R:function c3R(d,e,f){this.a=d
this.b=e
this.c=f},
c3L:function c3L(){},
c3M:function c3M(d,e){this.a=d
this.b=e},
c3K:function c3K(d,e){this.a=d
this.b=e},
c3N:function c3N(d,e){this.a=d
this.b=e},
c3J:function c3J(d,e,f){this.a=d
this.b=e
this.c=f},
c3I:function c3I(d,e){this.a=d
this.b=e},
c3O:function c3O(d){this.a=d},
c3P:function c3P(d){this.a=d},
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
clC(d,e){var x,w
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
D=c[61]
F=c[27]
G=c[35]
H=c[48]
B.qJ.prototype={
G4(d,e){var x=A.e5(e),w=y.X,v=A.kq(d,null,w),u=v==null?null:v.c.a
if((u==null?"":u)===x)return
F.ri(d,x,null,w,w)},
OO(d){return this.aYT(d)},
aYT(d){var x=0,w=A.l(y.H),v,u=2,t=[],s,r,q,p
var $async$OO=A.m(function(e,f){if(e===1){t.push(f)
x=u}for(;;)switch(x){case 0:q=C.e.l(d)
if(J.as(q)===0){x=1
break}u=4
x=7
return A.d(A.vF(A.zh(null,null,q,null,"mailto"),C.zo),$async$OO)
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
x=v}for(;;)switch(x){case 0:o=C.e.l(t.c.go)
n=o.length!==0
m=n?o:C.e.l(d)
if(C.e.b5(m,"http://")||C.e.b5(m,"https://"))q=A.bx(m,0,null)
else q=A.bx(n?o:"https://www.facebook.com/3tavs",0,null)
s=q
v=3
x=6
return A.d(A.vF(s,C.o9),$async$OP)
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
alh(d,e,f){var x=null,w=A.aR(d,C.x,x,18),v=f==null,u=A.L(A.a([w,C.aj,A.F(A.c(e,x,x,x,x,A.A(x,x,C.wX,x,!v?C.eR:C.a8,C.bp,x,x,x,x,x,12,x,x,x,x,x,!0,x,x,x,x,x,x,x,x),x,x,x),1)],y.p),C.E,C.k,C.q,0,x)
return v?u:A.cx(!1,x,!0,u,x,!0,x,x,x,x,x,x,x,x,x,x,f,x,x,x,x,x,x,x)},
a1A(d,e){return this.alh(d,e,null)},
D(d){var x=null
return A.P(x,A.dL(new B.avt(this,this.c)),C.v,C.nr,x,x,x,x,x,x,D.agc,x,x,x)}}
var z=a.updateTypes(["m5(S)"])
B.c3U.prototype={
$1(d){var x=null
return A.cL(A.a([A.bt(C.bQ,x,x,x,new B.c3S(d),x,x),A.dg(D.bBa,new B.c3T(d,this.a,this.b),x)],y.p),x,x,x,D.bE1,x,x,x,D.bEU,x)},
$S:10}
B.c3S.prototype={
$0(){A.R(this.a,!1).a2(null)
return null},
$S:0}
B.c3T.prototype={
$0(){var x=0,w=A.l(y.H),v=this
var $async$$0=A.m(function(d,e){if(d===1)return A.i(e,w)
for(;;)switch(x){case 0:A.R(v.a,!1).a2(null)
x=2
return A.d(A.bf(null,null,!0,null,new B.c3Q(),v.b,null,!0,!0,y.z),$async$$0)
case 2:x=3
return A.d(v.c.$0(),$async$$0)
case 3:return A.j(null,w)}})
return A.k($async$$0,w)},
$S:1}
B.c3Q.prototype={
$1(d){return G.qs},
$S:z+0}
B.c3V.prototype={
$1(d){return A.ax(d,y.N,y.z)},
$S:24}
B.c3W.prototype={
$1(d){var x,w=d.h(0,"status"),v=J.u(w==null?"":w).toLowerCase()
if(!J.n(v,"delivered"))return!1
x=d.h(0,"feedback_stars")
return x==null},
$S:17}
B.c3X.prototype={
$1(d){return new A.dU(new B.c3R(this.a,this.b,d),null)},
$S:19}
B.c3R.prototype={
$2(d,e){var x,w,v=null,u=this.a,t=u.b,s=A.c("Feedback \xb7 "+B.clC(t.h(0,"order_no"),t.h(0,"id")),v,v,v,v,v,v,v,v),r=y.p,q=A.a([],r),p=u.a
if(p.length>1){x=u.b
w=A.E(p).i("w<1,au<V<e,@>>>")
p=A.v(new A.w(p,new B.c3L(),w),w.i("aa.E"))
C.f.t(q,A.a([A.ey(D.amK,v,v,v,!0,!1,p,v,new B.c3M(u,e),v,x,y.P),C.K],r))}q.push(D.bGK)
q.push(C.D)
q.push(A.L(A.hM(5,new B.c3N(u,e),!0,y.l),C.u,C.k,C.q,0,v))
q.push(C.D)
q.push(A.aE(v,C.N,!1,v,!0,C.w,v,A.aF(),this.b,v,v,v,v,v,2,D.anN,C.A,!0,v,!0,v,!1,v,C.a2,v,v,v,v,v,v,v,v,4,v,v,!1,"\u2022",v,v,v,v,v,!1,v,v,!1,v,!0,v,C.U,v,v,v,v,v,v,v,v,v,v,v,v,!0,C.L,v,C.R,v,v,v,v))
u=A.bs(A.x(q,C.E,C.k,C.a1,0,C.t),v,C.A,v,v,v,C.a0)
q=this.c
return A.cL(A.a([A.bt(C.bQ,v,v,v,new B.c3O(q),v,v),A.dg(C.pe,new B.c3P(q),v)],r),v,v,v,u,v,v,v,s,v)},
$S:47}
B.c3L.prototype={
$1(d){var x=null
return A.e3(A.c(B.clC(d.h(0,"order_no"),d.h(0,"id")),x,x,x,x,x,x,x,x),d,y.P)},
$S:1180}
B.c3M.prototype={
$1(d){if(d==null)return
this.b.$1(new B.c3K(this.a,d))},
$S:1181}
B.c3K.prototype={
$0(){return this.a.b=this.b},
$S:0}
B.c3N.prototype={
$1(d){var x=null,w=this.a,v=d<w.c,u=v?C.jf:C.nZ
return A.aQ(x,x,x,A.aR(u,v?C.mj:x,x,x),x,x,new B.c3J(w,this.b,d),x,20,x,x,C.dN)},
$S:179}
B.c3J.prototype={
$0(){return this.b.$1(new B.c3I(this.a,this.c))},
$S:0}
B.c3I.prototype={
$0(){return this.a.c=this.b+1},
$S:0}
B.c3O.prototype={
$0(){A.R(this.a,!1).a2(!1)
return null},
$S:0}
B.c3P.prototype={
$0(){A.R(this.a,!1).a2(!0)
return null},
$S:0}
B.avt.prototype={
$2(d,e){var x,w,v,u,t,s=null,r=e.b>900,q=r?s:220,p=this.b,o=y.p,n=A.a([A.bt(A.c(p.fr,s,s,s,s,D.bwV,s,s,s),s,s,s,new B.avj(d,p),s,s),A.kB(D.byD,C.L,p.y1)],o),m=this.a
if(m.d)n.push(A.hm(D.alA,D.bGa,new B.avk(m,d,p),s))
q=A.af(A.x(n,C.E,C.k,C.q,0,C.t),s,q)
n=A.x(A.a([A.bt(A.c("Gallery",s,s,s,s,D.mJ,s,s,s),s,s,s,new B.avl(m,d),s,s),A.bt(A.c("Catering Menu",s,s,s,s,D.mJ,s,s,s),s,s,s,new B.avm(m,d),s,s),A.bt(A.c("Restaurant",s,s,s,s,D.mJ,s,s,s),s,s,s,new B.avn(m,d),s,s)],o),C.E,C.k,C.q,0,C.t)
x=A.x(A.a([A.bt(A.c("Inquire Now",s,s,s,s,D.mJ,s,s,s),s,s,s,new B.avo(m,d),s,s),A.bt(A.c("Contact Us",s,s,s,s,D.mJ,s,s,s),s,s,s,new B.avp(m,d),s,s),A.bt(D.bJ0,s,s,s,new B.avq(m,d),s,s)],o),C.E,C.k,C.q,0,C.t)
w=p.rx
v=A.aR(E.yN,C.x,s,18)
w=A.cx(!1,s,!0,A.L(A.a([v,C.aj,A.F(A.c(w,s,s,s,s,A.A(s,s,C.x,s,C.eR,C.bp,s,s,s,s,s,12,s,s,s,s,s,!0,s,s,s,s,s,s,s,s),s,s,s),1)],o),C.E,C.k,C.q,0,s),s,!0,s,s,s,s,s,s,s,s,s,s,new B.avr(m,p),s,s,s,s,s,s,s)
u=A.a([q,n,x,A.af(w,s,200),A.x(A.a([m.a1A(E.yV,p.ry),m.a1A(E.yY,p.to)],o),C.E,C.k,C.q,0,C.t),A.x(A.a([m.a1A(E.r3,p.x1),m.alh(E.yM,p.x2,new B.avs(m,p))],o),C.E,C.k,C.q,0,C.t)],o)
if(r){q=A.a([],o)
for(t=0;t<6;++t){p=A.a([],o)
if(t>0)p.push(D.bqG)
p.push(new A.dP(1,C.c6,u[t],s))
C.f.t(q,p)}q.push(C.db)
q.push(A.na("lib/assets/main-2.png",C.at,!1,C.c2,C.c_,72,s))
return A.L(q,C.E,C.k,C.q,0,s)}return A.ch(C.aR,u,C.aU,12,24)},
$S:1182}
B.avj.prototype={
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
w=A.kB(D.buL,C.L,A.bF(u,w,""))
A.eu(A.a([new A.dz("Close",null,new B.avi(x),!1,null)],y.p),!0,w,x,560,!0,v,y.H)},
$S:0}
B.avi.prototype={
$0(){A.R(this.a,!1).a2(null)
return null},
$S:0}
B.avk.prototype={
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
B.avl.prototype={
$0(){return this.a.G4(this.b,"/gallery")},
$S:0}
B.avm.prototype={
$0(){return this.a.G4(this.b,"/catering-menu")},
$S:0}
B.avn.prototype={
$0(){return this.a.G4(this.b,"/restaurant")},
$S:0}
B.avo.prototype={
$0(){return this.a.G4(this.b,"/inquire")},
$S:0}
B.avp.prototype={
$0(){return this.a.G4(this.b,"/contact-us")},
$S:0}
B.avq.prototype={
$0(){var x=this.a,w=x.f
if(w==null)w=new B.avh()
return B.Em(this.b,x.e,w)},
$S:0}
B.avh.prototype={
$0(){var x=0,w=A.l(y.H)
var $async$$0=A.m(function(d,e){if(d===1)return A.i(e,w)
for(;;)switch(x){case 0:return A.j(null,w)}})
return A.k($async$$0,w)},
$S:1}
B.avr.prototype={
$0(){return this.a.OP(this.b.rx)},
$S:0}
B.avs.prototype={
$0(){return this.a.OO(this.b.x2)},
$S:0};(function inheritance(){var x=a.inheritMany,w=a.inherit
x(A.ht,[B.c3U,B.c3Q,B.c3V,B.c3W,B.c3X,B.c3L,B.c3M,B.c3N])
x(A.jG,[B.c3S,B.c3T,B.c3K,B.c3J,B.c3I,B.c3O,B.c3P,B.avj,B.avi,B.avk,B.avl,B.avm,B.avn,B.avo,B.avp,B.avq,B.avh,B.avr,B.avs])
x(A.kM,[B.c3R,B.avt])
w(B.qJ,A.ap)})()
A.kF(b.typeUniverse,JSON.parse('{"qJ":{"ap":[],"f":[]}}'))
var y=(function rtii(){var x=A.ak
return{p:x("G<f>"),P:x("V<e,@>"),f:x("V<@,@>"),K:x("a8"),N:x("e"),l:x("f"),q:x("t9"),y:x("O"),z:x("@"),g:x("Y<@>?"),X:x("a8?"),H:x("~")}})();(function constants(){D.agc=new A.ac(40,20,40,20)
D.alA=new A.aj(C.hP,14,C.bp,null,null)
D.amK=new A.aW(null,null,null,"Order",null,null,null,null,null,null,null,null,null,null,null,null,!0,!0,!1,null,null,null,null,null,null,!0,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,!0,null,null,null,null)
D.anN=new A.aW(null,null,null,"Remarks",null,null,null,null,null,null,"Optional comments about your completed order",null,null,null,null,null,!0,!0,!1,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,!0,null,null,null,null)
D.bqG=new A.bk(28,null,null,null)
D.bBI=new A.o("Failed to submit feedback",null,null,null,null,null,null,null,null,null,null)
D.brz=new A.c3(D.bBI,null,null,null,null,null,null,null,null,null,null,null,null,C.ab,!1,null,null,null,C.w,null)
D.bGX=new A.o("Thank you for your feedback",null,null,null,null,null,null,null,null,null,null)
D.brT=new A.c3(D.bGX,null,null,null,null,null,null,null,null,null,null,null,null,C.ab,!1,null,null,null,C.w,null)
D.bE8=new A.o("No delivered restaurant orders available for feedback",null,null,null,null,null,null,null,null,null,null)
D.brU=new A.c3(D.bE8,null,null,null,null,null,null,null,null,null,null,null,null,C.ab,!1,null,null,null,C.w,null)
D.bH1=new A.o("Please log in to submit feedback",null,null,null,null,null,null,null,null,null,null)
D.brV=new A.c3(D.bH1,null,null,null,null,null,null,null,null,null,null,null,null,C.ab,!1,null,null,null,C.w,null)
D.bI9=new A.o("Could not load your orders",null,null,null,null,null,null,null,null,null,null)
D.a10=new A.c3(D.bI9,null,null,null,null,null,null,null,null,null,null,null,null,C.ab,!1,null,null,null,C.w,null)
D.abm=new A.Q(1,0.12156862745098039,0.1607843137254902,0.21568627450980393,C.F)
D.buL=new A.M(!0,D.abm,null,null,null,null,14,null,null,null,null,null,1.55,null,null,null,null,null,null,null,null,null,null,null,null,null)
D.bwV=new A.M(!0,C.T,null,null,null,null,null,C.a9,null,null,null,null,null,null,null,null,null,C.eR,C.T,null,null,null,null,null,null,null)
D.aaw=new A.Q(1,0.9098039215686274,0.9176470588235294,0.9294117647058824,C.F)
D.byD=new A.M(!0,D.aaw,null,null,null,null,11,null,null,null,null,null,1.4,null,null,null,null,null,null,null,null,null,null,null,null,null)
D.mJ=new A.M(!0,C.wX,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null)
D.bBa=new A.o("Log in",null,null,null,null,null,null,null,null,null,null)
D.bE1=new A.o("Please log in to share feedback on a completed order.",null,null,null,null,null,null,null,null,null,null)
D.bEU=new A.o("Feedback",null,null,null,null,null,null,null,null,null,null)
D.bGa=new A.o("Edit",null,H.a1C,null,null,null,null,null,null,null,null)
D.bGK=new A.o("How was this restaurant order?",null,null,null,null,null,null,null,null,null,null)
D.bJ0=new A.o("Feedback",null,D.mJ,null,null,null,null,null,null,null,null)})()};
(a=>{a["QTZGDr3TIfCwlQnui34kpDKEwas="]=a.current})($__dart_deferred_initializers__);