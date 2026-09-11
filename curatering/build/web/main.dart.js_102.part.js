((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,A,C,B={
crc(d,e){var x=new A.aI($.aX,e.i("aI<0>"))
A.iK(new B.aAh(d,x))
return x},
aAh:function aAh(d,e){this.a=d
this.b=e},
c5U(d){var x,w,v,u="created_at",t=d.h(0,"dish_ids"),s=t==null?d.h(0,"dishIds"):t
if(s==null)s=C.bv
t=A.aL(d.h(0,"id"))
if(t==null)t=""
x=A.aL(d.h(0,"name"))
if(x==null)x=""
if(y.i.b(s)){w=J.cj(s,new B.aRc(),y.w).cH(0,new B.aRd())
w=A.v(w,w.$ti.i("r.E"))}else w=C.O
v=A.ks(d.h(0,"archived"))
if(d.h(0,u)!=null)E.et(J.w(d.h(0,u)))
return new B.f9(t,x,w,v===!0)},
cvd(){var x=new B.aaX($.a0())
x.aF6()
return x},
f9:function f9(d,e,f,g){var _=this
_.a=d
_.b=e
_.c=f
_.d=g},
aRc:function aRc(){},
aRd:function aRd(){},
aaX:function aaX(d){var _=this
_.a=$
_.b=!1
_.I$=0
_.J$=d
_.aL$=_.aR$=0},
aR8:function aR8(d){this.a=d},
aRa:function aRa(){},
aR9:function aR9(){},
aRb:function aRb(d,e){this.a=d
this.b=e}},D,E
J=c[1]
A=c[0]
C=c[2]
B=a.updateHolder(c[28],B)
D=c[74]
E=c[71]
B.f9.prototype={}
B.aaX.prototype={
aF6(){this.a=A.a([],y.k)
B.crc(new B.aR8(this),y.v)},
mT(){var x=0,w=A.l(y.v),v=1,u=[],t=this,s,r,q,p,o,n
var $async$mT=A.m(function(d,e){if(d===1){u.push(e)
x=v}for(;;)switch(x){case 0:v=3
t.b=!0
t.a4()
x=6
return A.d($.bM().vW("/api/menu/set-menus"),$async$mT)
case 6:s=e
r=J.t(s,"setMenus")
if(!y.i.b(r))t.a=A.a([],y.k)
else{p=J.cj(r,new B.aRa(),y.e)
p=A.v(p,p.$ti.i("ab.E"))
t.a=p}t.b=!1
t.a4()
v=1
x=5
break
case 3:v=2
n=u.pop()
q=A.a9(n)
D.er().$1("Error loading set menus: "+A.h(q))
J.w(q)
t.b=!1
t.a4()
x=5
break
case 2:x=1
break
case 5:return A.j(null,w)
case 1:return A.i(u.at(-1),w)}})
return A.k($async$mT,w)},
gil(){var x,w=this.a
w===$&&A.b()
x=A.F(w).i("V<1>")
w=A.v(new A.V(w,new B.aR9(),x),x.i("r.E"))
return w},
RI(d,e){return this.bdo(d,e)},
bdo(d,e){var x=0,w=A.l(y.v),v=1,u=[],t=this,s,r,q,p,o,n,m
var $async$RI=A.m(function(f,g){if(f===1){u.push(g)
x=v}for(;;)switch(x){case 0:v=3
x=6
return A.d($.bM().e0("/api/set-menus",A.Q(["name",C.e.l(e),"dishIds",d],y.w,y.b)),$async$RI)
case 6:s=g
r=B.c5U(y.y.a(J.t(s,"setMenu")))
o=t.a
o===$&&A.b()
o=A.v(o,y.e)
q=o
J.bS(q,r)
t.a=q
t.a4()
v=1
x=5
break
case 3:v=2
m=u.pop()
p=A.a9(m)
D.er().$1("Error adding set menu: "+A.h(p))
throw m
x=5
break
case 2:x=1
break
case 5:return A.j(null,w)
case 1:return A.i(u.at(-1),w)}})
return A.k($async$RI,w)},
VV(d,e,f){return this.brb(d,e,f)},
brb(d,e,f){var x=0,w=A.l(y.v),v=1,u=[],t=this,s,r,q,p,o,n,m
var $async$VV=A.m(function(g,h){if(g===1){u.push(h)
x=v}for(;;)switch(x){case 0:v=3
x=6
return A.d($.bM().kM("/api/set-menus/"+e,A.Q(["name",C.e.l(f),"dishIds",d],y.w,y.b)),$async$VV)
case 6:s=h
r=B.c5U(y.y.a(J.t(s,"setMenu")))
p=t.a
p===$&&A.b()
o=A.F(p).i("x<1,f9>")
p=A.v(new A.x(p,new B.aRb(e,r),o),o.i("ab.E"))
t.a=p
t.a4()
v=1
x=5
break
case 3:v=2
m=u.pop()
q=A.a9(m)
D.er().$1("Error updating set menu: "+A.h(q))
throw m
x=5
break
case 2:x=1
break
case 5:return A.j(null,w)
case 1:return A.i(u.at(-1),w)}})
return A.k($async$VV,w)}}
var z=a.updateTypes(["f9(@)","H(f9)","f9(f9)"])
B.aAh.prototype={
$0(){var x,w,v,u,t,s,r=null
try{r=this.a.$0()}catch(v){x=A.a9(v)
w=A.be(v)
u=x
t=w
s=A.Es(u,t)
u=new A.h2(u,t)
this.b.kl(u)
return}this.b.tH(r)},
$S:0}
B.aRc.prototype={
$1(d){return J.w(d)},
$S:13}
B.aRd.prototype={
$1(d){return d.length!==0},
$S:3}
B.aR8.prototype={
$0(){return this.a.mT()},
$S:2}
B.aRa.prototype={
$1(d){return B.c5U(y.y.a(d))},
$S:z+0}
B.aR9.prototype={
$1(d){return!d.d},
$S:z+1}
B.aRb.prototype={
$1(d){return d.a===this.a?this.b:d},
$S:z+2};(function inheritance(){var x=a.inheritMany,w=a.inherit
x(A.dY,[B.aAh,B.aR8])
w(B.f9,A.W)
x(A.d9,[B.aRc,B.aRd,B.aRa,B.aR9,B.aRb])
w(B.aaX,A.hH)})()
A.dl(b.typeUniverse,JSON.parse('{"aaX":{"aJ":[]}}'))
var y={k:A.X("y<f9>"),i:A.X("a_<@>"),y:A.X("S<e,@>"),e:A.X("f9"),w:A.X("e"),b:A.X("@"),v:A.X("~")};(function lazyInitializers(){var x=a.lazyFinal
x($,"cJ0","fd",()=>B.cvd())})()};
(a=>{a["flmDwKL90CvCCydyvj68uZKcklU="]=a.current})($__dart_deferred_initializers__);