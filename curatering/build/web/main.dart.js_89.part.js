((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,A,C,D,E,B={
cr6(d,e){var x=new A.aI($.aX,e.i("aI<0>"))
A.iK(new B.aAe(d,x))
return x},
aAe:function aAe(d,e){this.a=d
this.b=e},
c5Q(d){var x,w,v,u="created_at",t=d.h(0,"dish_ids"),s=t==null?d.h(0,"dishIds"):t
if(s==null)s=C.bv
t=A.aL(d.h(0,"id"))
if(t==null)t=""
x=A.aL(d.h(0,"name"))
if(x==null)x=""
if(y.i.b(s)){w=J.cj(s,new B.aR7(),y.w).cH(0,new B.aR8())
w=A.v(w,w.$ti.i("r.E"))}else w=C.O
v=A.ks(d.h(0,"archived"))
if(d.h(0,u)!=null)E.es(J.w(d.h(0,u)))
return new B.f9(t,x,w,v===!0)},
cv6(){var x=new B.aaW($.a0())
x.aF4()
return x},
f9:function f9(d,e,f,g){var _=this
_.a=d
_.b=e
_.c=f
_.d=g},
aR7:function aR7(){},
aR8:function aR8(){},
aaW:function aaW(d){var _=this
_.a=$
_.b=!1
_.I$=0
_.J$=d
_.aL$=_.aR$=0},
aR3:function aR3(d){this.a=d},
aR5:function aR5(){},
aR4:function aR4(){},
aR6:function aR6(d,e){this.a=d
this.b=e}}
J=c[1]
A=c[0]
C=c[2]
D=c[69]
E=c[67]
B=a.updateHolder(c[27],B)
B.f9.prototype={}
B.aaW.prototype={
aF4(){this.a=A.a([],y.k)
B.cr6(new B.aR3(this),y.v)},
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
else{p=J.cj(r,new B.aR5(),y.e)
p=A.v(p,p.$ti.i("ab.E"))
t.a=p}t.b=!1
t.a4()
v=1
x=5
break
case 3:v=2
n=u.pop()
q=A.a9(n)
D.eq().$1("Error loading set menus: "+A.h(q))
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
w=A.v(new A.V(w,new B.aR4(),x),x.i("r.E"))
return w},
RI(d,e){return this.bdj(d,e)},
bdj(d,e){var x=0,w=A.l(y.v),v=1,u=[],t=this,s,r,q,p,o,n,m
var $async$RI=A.m(function(f,g){if(f===1){u.push(g)
x=v}for(;;)switch(x){case 0:v=3
x=6
return A.d($.bM().e0("/api/set-menus",A.Q(["name",C.e.m(e),"dishIds",d],y.w,y.b)),$async$RI)
case 6:s=g
r=B.c5Q(y.y.a(J.t(s,"setMenu")))
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
D.eq().$1("Error adding set menu: "+A.h(p))
throw m
x=5
break
case 2:x=1
break
case 5:return A.j(null,w)
case 1:return A.i(u.at(-1),w)}})
return A.k($async$RI,w)},
VU(d,e,f){return this.br5(d,e,f)},
br5(d,e,f){var x=0,w=A.l(y.v),v=1,u=[],t=this,s,r,q,p,o,n,m
var $async$VU=A.m(function(g,h){if(g===1){u.push(h)
x=v}for(;;)switch(x){case 0:v=3
x=6
return A.d($.bM().kM("/api/set-menus/"+e,A.Q(["name",C.e.m(f),"dishIds",d],y.w,y.b)),$async$VU)
case 6:s=h
r=B.c5Q(y.y.a(J.t(s,"setMenu")))
p=t.a
p===$&&A.b()
o=A.F(p).i("x<1,f9>")
p=A.v(new A.x(p,new B.aR6(e,r),o),o.i("ab.E"))
t.a=p
t.a4()
v=1
x=5
break
case 3:v=2
m=u.pop()
q=A.a9(m)
D.eq().$1("Error updating set menu: "+A.h(q))
throw m
x=5
break
case 2:x=1
break
case 5:return A.j(null,w)
case 1:return A.i(u.at(-1),w)}})
return A.k($async$VU,w)}}
var z=a.updateTypes(["f9(@)","H(f9)","f9(f9)"])
B.aAe.prototype={
$0(){var x,w,v,u,t,s,r=null
try{r=this.a.$0()}catch(v){x=A.a9(v)
w=A.be(v)
u=x
t=w
s=A.Er(u,t)
u=new A.h2(u,t)
this.b.kl(u)
return}this.b.tI(r)},
$S:0}
B.aR7.prototype={
$1(d){return J.w(d)},
$S:13}
B.aR8.prototype={
$1(d){return d.length!==0},
$S:3}
B.aR3.prototype={
$0(){return this.a.mT()},
$S:2}
B.aR5.prototype={
$1(d){return B.c5Q(y.y.a(d))},
$S:z+0}
B.aR4.prototype={
$1(d){return!d.d},
$S:z+1}
B.aR6.prototype={
$1(d){return d.a===this.a?this.b:d},
$S:z+2};(function inheritance(){var x=a.inheritMany,w=a.inherit
x(A.ed,[B.aAe,B.aR3])
w(B.f9,A.W)
x(A.de,[B.aR7,B.aR8,B.aR5,B.aR4,B.aR6])
w(B.aaW,A.hH)})()
A.dF(b.typeUniverse,JSON.parse('{"aaW":{"aJ":[]}}'))
var y={k:A.Y("z<f9>"),i:A.Y("a_<@>"),y:A.Y("S<e,@>"),e:A.Y("f9"),w:A.Y("e"),b:A.Y("@"),v:A.Y("~")};(function lazyInitializers(){var x=a.lazyFinal
x($,"cIT","fd",()=>B.cv6())})()};
(a=>{a["uJazqBHxwcsSIzbLHDh63Gr80AA="]=a.current})($__dart_deferred_initializers__);