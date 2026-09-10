((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,A,C,D,E,F,B={
c4P(d,e){var x,w,v,u,t,s,r,q,p,o,n=new B.aua(),m=new B.au9(),l=new B.au8(),k=d.h(0,"positive_prompt")
if(k==null)k=d.h(0,"prompt")
x=C.e.k(A.h(k==null?e:k))
if(x.length===0)throw A.q(A.bF("NLP prompt expansion returned no positive prompt."))
k=d.h(0,"negative_prompt")
k=C.e.k(A.h(k==null?"":k))
w=n.$1(d.h(0,"theme_tokens"))
v=n.$1(d.h(0,"lighting_tokens"))
u=n.$1(d.h(0,"style_tokens"))
t=n.$1(d.h(0,"decor_tokens"))
s=n.$1(d.h(0,"decor_elements"))
r=d.h(0,"visual_keywords")
n=n.$1(r==null?d.h(0,"visual_direction"):r)
r=d.h(0,"recommended_strength")
r=m.$1(r==null?d.h(0,"strength"):r)
m=m.$1(d.h(0,"cfg_scale"))
q=new B.au7().$1(d.h(0,"steps"))
p=l.$1(d.h(0,"controlnet"))
o=d.h(0,"mode")
o=o==null?null:J.u(o)
return new B.a1V(x,k,w,v,u,t,s,n,r,m,q,p,o,l.$1(d.h(0,"transformation_plan")))},
aJ6(d){var x=y.w,w=y.b
return y.B.b(d)?A.aH(d,x,w):A.J(x,w)},
c7a(d){var x,w,v=B.aJ6(d.h(0,"output")),u=B.aJ6(v.h(0,"result"))
if(u.a!==0)return u
x=B.aJ6(v.h(0,"analysis"))
if(x.a!==0)return x
if(v.a!==0)return v
w=B.aJ6(d.h(0,"result"))
if(w.a!==0)return w
return d},
PW(d,e){return B.cmr(d,e)},
cmr(d,e){var x=0,w=A.m(y.q),v,u=2,t=[],s,r,q,p,o,n,m,l,k,j,i,h,g
var $async$PW=A.n(function(f,a0){if(f===1){t.push(a0)
x=u}for(;;)switch(x){case 0:u=4
if(D.wI().length===0)A.ap(A.bF("API_BASE_URL is empty; set --dart-define=API_BASE_URL=... so the RunPod proxy can be reached."))
k=y.w
s=A.f9(d,k,y.b)
J.bg(s,"task_type","event_prompt_expansion")
r=s
s=A.by(D.wI()+"/api/public/runpod/nlp/run",0,null)
j=A.M(["Content-Type","application/json"],k,k)
i=y.y
x=7
return A.d(A.ej(s,C.a4.ca(A.M(["input",r],k,i),null),null,j).cr(C.pU),$async$PW)
case 7:q=a0
if(q.b!==200)D.c_h(q)
s=q
p=i.a(C.a4.bl(A.cr(A.cq(s.e)).bb(s.w),null))
o=D.a6x(J.a8(p,"status"))
n=D.c79(p)
if(o==="COMPLETED"||J.a8(p,"output")!=null){s=B.c4P(B.c7a(p),e)
v=s
x=1
break}s=o
if(s==="FAILED"||s==="CANCELLED"){s=A.bF(D.aJ5(p))
throw A.q(s)}if(n==null||n.length===0){s=A.bF("NLP prompt expansion did not return a job id.")
throw A.q(s)}x=8
return A.d(B.a6y(n),$async$PW)
case 8:m=a0
s=B.c4P(B.c7a(m),e)
v=s
x=1
break
u=2
x=6
break
case 4:u=3
g=t.pop()
l=A.a7(g)
s=A.bF("Failed to expand event prompt: "+A.h(l))
throw A.q(s)
x=6
break
case 3:x=2
break
case 6:case 1:return A.k(v,w)
case 2:return A.j(t.at(-1),w)}})
return A.l($async$PW,w)},
a6y(d){return B.cmp(d)},
cmp(d){var x=0,w=A.m(y.y),v,u=2,t=[],s,r,q,p,o,n,m,l,k,j,i,h,g,f,e
var $async$a6y=A.n(function(a0,a1){if(a0===1){t.push(a1)
x=u}for(;;)switch(x){case 0:g=0
f=null
m=y.g,l=y.b,k=y.y
case 3:if(!(g<130)){x=4
break}x=5
return A.d(A.h4(E.pV,null,l),$async$a6y)
case 5:++g
u=7
x=10
return A.d(A.fJ(A.by(D.wI()+"/api/public/runpod/nlp/status/"+A.eN(2,d,C.bb,!1),0,null),null).cr(F.f3),$async$a6y)
case 10:s=a1
if(s.b===429){j=A.bF("Too many requests \u2014 wait a moment and try again.")
throw A.q(j)}if(s.b===200){j=s
r=k.a(C.a4.bl(A.cr(A.cq(j.e)).bb(j.w),null))
q=D.a6x(J.a8(r,"status"))
if(q==="COMPLETED"){j=r
v=j
x=1
break}j=q
if(j==="FAILED"||j==="CANCELLED"){j=A.bF(D.aJ5(r))
throw A.q(j)}}else D.c_h(s)
u=2
x=9
break
case 7:u=6
e=t.pop()
j=A.a7(e)
if(m.b(j)){p=j
o=J.u(p)
if(J.iv(o,"Job failed")||J.iv(o,"AI generation exceeded")||J.iv(o,"Worker returned"))throw e
f=p
A.ZK("NLP polling error (attempt "+A.h(g)+"): "+A.h(p))}else{n=j
f=n
j=A.h(g)
h=A.h(n)
A.ZK("NLP polling error (attempt "+j+"): "+h)}x=9
break
case 6:x=2
break
case 9:x=3
break
case 4:if(m.b(f))throw A.q(f)
throw A.q(A.bF("NLP task timed out after 650s waiting for the AI worker. Try again in a moment."))
case 1:return A.k(v,w)
case 2:return A.j(t.at(-1),w)}})
return A.l($async$a6y,w)},
a1V:function a1V(d,e,f,g,h,i,j,k,l,m,n,o,p,q){var _=this
_.a=d
_.b=e
_.c=f
_.d=g
_.e=h
_.f=i
_.r=j
_.w=k
_.x=l
_.y=m
_.z=n
_.Q=o
_.as=p
_.at=q},
aua:function aua(){},
aub:function aub(){},
auc:function auc(){},
au9:function au9(){},
au7:function au7(){},
au8:function au8(){}},G
J=c[1]
A=c[0]
C=c[2]
D=c[20]
E=c[27]
F=c[28]
B=a.updateHolder(c[14],B)
G=c[33]
B.a1V.prototype={
arq(){var x,w,v=this,u=A.J(y.w,y.b)
u.p(0,"positive_prompt",v.a)
x=v.b
if(x.length!==0)u.p(0,"negative_prompt",x)
u.p(0,"theme_tokens",v.c)
u.p(0,"lighting_tokens",v.d)
u.p(0,"style_tokens",v.e)
u.p(0,"decor_tokens",v.f)
u.p(0,"decor_elements",v.r)
u.p(0,"visual_keywords",v.w)
x=v.x
w=x!=null
if(w)u.p(0,"recommended_strength",x)
if(w)u.p(0,"strength",x)
x=v.y
if(x!=null)u.p(0,"cfg_scale",x)
x=v.z
if(x!=null)u.p(0,"steps",x)
x=v.Q
if(x!=null)u.p(0,"controlnet",x)
x=v.as
if(x!=null&&x.length!==0)u.p(0,"mode",x)
x=v.at
if(x!=null)u.p(0,"transformation_plan",x)
u.p(0,"nlp_expansion",v.be())
return u},
be(){var x,w,v=this,u=A.J(y.w,y.b)
u.p(0,"positive_prompt",v.a)
u.p(0,"negative_prompt",v.b)
u.p(0,"theme_tokens",v.c)
u.p(0,"lighting_tokens",v.d)
u.p(0,"style_tokens",v.e)
u.p(0,"decor_tokens",v.f)
u.p(0,"decor_elements",v.r)
u.p(0,"visual_keywords",v.w)
x=v.x
w=x!=null
if(w)u.p(0,"recommended_strength",x)
if(w)u.p(0,"strength",x)
x=v.y
if(x!=null)u.p(0,"cfg_scale",x)
x=v.z
if(x!=null)u.p(0,"steps",x)
x=v.Q
if(x!=null)u.p(0,"controlnet",x)
x=v.as
if(x!=null&&x.length!==0)u.p(0,"mode",x)
x=v.at
if(x!=null)u.p(0,"transformation_plan",x)
return u}}
var z=a.updateTypes([])
B.aua.prototype={
$1(d){var x
y.d.a(d)
x=d==null?C.bs:d
x=J.c8(x,new B.aub(),y.w).cu(0,new B.auc())
x=A.x(x,x.$ti.i("y.E"))
return x},
$S:243}
B.aub.prototype={
$1(d){return C.e.k(A.h(d))},
$S:14}
B.auc.prototype={
$1(d){return d.length!==0},
$S:4}
B.au9.prototype={
$1(d){if(typeof d=="number")return d
return A.bx(A.h(d))},
$S:250}
B.au7.prototype={
$1(d){if(typeof d=="number")return C.p.aD(d)
return A.cd(A.h(d),null)},
$S:952}
B.au8.prototype={
$1(d){if(y.B.b(d))return A.aH(d,y.w,y.b)
return null},
$S:235};(function inheritance(){var x=a.inherit,w=a.inheritMany
x(B.a1V,A.Z)
w(A.i6,[B.aua,B.aub,B.auc,B.au9,B.au7,B.au8])})()
var y={q:A.an("a1V"),g:A.an("cl"),y:A.an("R<e,@>"),B:A.an("R<@,@>"),w:A.an("e"),b:A.an("@"),d:A.an("a2<@>?")};(function constants(){G.GH=new A.ai(57531,"MaterialIcons",!1)})()};
(a=>{a["A7Hu81rFzqapBANIU8yxKDi3sLY="]=a.current})($__dart_deferred_initializers__);