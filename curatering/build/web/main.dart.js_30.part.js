((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,A,C,D,E,F,B={
cba(d,e){var x,w,v,u,t,s,r,q,p,o,n=new B.aym(),m=new B.ayl(),l=new B.ayk(),k=d.h(0,"positive_prompt")
if(k==null)k=d.h(0,"prompt")
x=C.e.m(A.h(k==null?e:k))
if(x.length===0)throw A.p(A.bA("NLP prompt expansion returned no positive prompt."))
k=d.h(0,"negative_prompt")
k=C.e.m(A.h(k==null?"":k))
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
q=new B.ayj().$1(d.h(0,"steps"))
p=l.$1(d.h(0,"controlnet"))
o=d.h(0,"mode")
o=o==null?null:J.w(o)
return new B.a4W(x,k,w,v,u,t,s,n,r,m,q,p,o,l.$1(d.h(0,"transformation_plan")))},
aO3(d){var x=y.w,w=y.b
return y.B.b(d)?A.aD(d,x,w):A.H(x,w)},
ce0(d){var x,w,v=B.aO3(d.h(0,"output")),u=B.aO3(v.h(0,"result"))
if(u.a!==0)return u
x=B.aO3(v.h(0,"analysis"))
if(x.a!==0)return x
if(v.a!==0)return v
w=B.aO3(d.h(0,"result"))
if(w.a!==0)return w
return d},
SM(d,e){return B.cub(d,e)},
cub(d,e){var x=0,w=A.l(y.q),v,u=2,t=[],s,r,q,p,o,n,m,l,k,j,i,h,g
var $async$SM=A.m(function(f,a0){if(f===1){t.push(a0)
x=u}for(;;)switch(x){case 0:u=4
if(D.yb().length===0)A.aq(A.bA("API_BASE_URL is empty; set --dart-define=API_BASE_URL=... so the RunPod proxy can be reached."))
k=y.w
s=A.f_(d,k,y.b)
J.az(s,"task_type","event_prompt_expansion")
r=s
s=A.bE(D.yb()+"/api/public/runpod/nlp/run",0,null)
j=A.Q(["Content-Type","application/json"],k,k)
i=y.y
x=7
return A.d(A.eF(s,C.a4.cr(A.Q(["input",r],k,i),null),null,j).cM(C.qB),$async$SM)
case 7:q=a0
if(q.b!==200)D.c5r(q)
s=q
p=i.a(C.a4.bu(A.cF(A.cE(s.e)).ba(s.w),null))
o=D.aaf(J.t(p,"status"))
n=D.ce_(p)
if(o==="COMPLETED"||J.t(p,"output")!=null){s=B.cba(B.ce0(p),e)
v=s
x=1
break}s=o
if(s==="FAILED"||s==="CANCELLED"){s=A.bA(D.aO2(p))
throw A.p(s)}if(n==null||n.length===0){s=A.bA("NLP prompt expansion did not return a job id.")
throw A.p(s)}x=8
return A.d(B.aag(n),$async$SM)
case 8:m=a0
s=B.cba(B.ce0(m),e)
v=s
x=1
break
u=2
x=6
break
case 4:u=3
g=t.pop()
l=A.a8(g)
s=A.bA("Failed to expand event prompt: "+A.h(l))
throw A.p(s)
x=6
break
case 3:x=2
break
case 6:case 1:return A.j(v,w)
case 2:return A.i(t.at(-1),w)}})
return A.k($async$SM,w)},
aag(d){return B.cu9(d)},
cu9(d){var x=0,w=A.l(y.y),v,u=2,t=[],s,r,q,p,o,n,m,l,k,j,i,h,g,f,e
var $async$aag=A.m(function(a0,a1){if(a0===1){t.push(a1)
x=u}for(;;)switch(x){case 0:g=0
f=null
m=y.g,l=y.b,k=y.y
case 3:if(!(g<130)){x=4
break}x=5
return A.d(A.hH(E.qD,null,l),$async$aag)
case 5:++g
u=7
x=10
return A.d(A.hb(A.bE(D.yb()+"/api/public/runpod/nlp/status/"+A.f7(2,d,C.ba,!1),0,null),null).cM(F.fh),$async$aag)
case 10:s=a1
if(s.b===429){j=A.bA("Too many requests \u2014 wait a moment and try again.")
throw A.p(j)}if(s.b===200){j=s
r=k.a(C.a4.bu(A.cF(A.cE(j.e)).ba(j.w),null))
q=D.aaf(J.t(r,"status"))
if(q==="COMPLETED"){j=r
v=j
x=1
break}j=q
if(j==="FAILED"||j==="CANCELLED"){j=A.bA(D.aO2(r))
throw A.p(j)}}else D.c5r(s)
u=2
x=9
break
case 7:u=6
e=t.pop()
j=A.a8(e)
if(m.b(j)){p=j
o=J.w(p)
if(J.jv(o,"Job failed")||J.jv(o,"AI generation exceeded")||J.jv(o,"Worker returned"))throw e
f=p
A.a1B("NLP polling error (attempt "+A.h(g)+"): "+A.h(p))}else{n=j
f=n
j=A.h(g)
h=A.h(n)
A.a1B("NLP polling error (attempt "+j+"): "+h)}x=9
break
case 6:x=2
break
case 9:x=3
break
case 4:if(m.b(f))throw A.p(f)
throw A.p(A.bA("NLP task timed out after 650s waiting for the AI worker. Try again in a moment."))
case 1:return A.j(v,w)
case 2:return A.i(t.at(-1),w)}})
return A.k($async$aag,w)},
a4W:function a4W(d,e,f,g,h,i,j,k,l,m,n,o,p,q){var _=this
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
aym:function aym(){},
ayn:function ayn(){},
ayo:function ayo(){},
ayl:function ayl(){},
ayj:function ayj(){},
ayk:function ayk(){}},G
J=c[1]
A=c[0]
C=c[2]
D=c[20]
E=c[54]
F=c[55]
B=a.updateHolder(c[13],B)
G=c[60]
B.a4W.prototype={
avk(){var x,w,v=this,u=A.H(y.w,y.b)
u.k(0,"positive_prompt",v.a)
x=v.b
if(x.length!==0)u.k(0,"negative_prompt",x)
u.k(0,"theme_tokens",v.c)
u.k(0,"lighting_tokens",v.d)
u.k(0,"style_tokens",v.e)
u.k(0,"decor_tokens",v.f)
u.k(0,"decor_elements",v.r)
u.k(0,"visual_keywords",v.w)
x=v.x
w=x!=null
if(w)u.k(0,"recommended_strength",x)
if(w)u.k(0,"strength",x)
x=v.y
if(x!=null)u.k(0,"cfg_scale",x)
x=v.z
if(x!=null)u.k(0,"steps",x)
x=v.Q
if(x!=null)u.k(0,"controlnet",x)
x=v.as
if(x!=null&&x.length!==0)u.k(0,"mode",x)
x=v.at
if(x!=null)u.k(0,"transformation_plan",x)
u.k(0,"nlp_expansion",v.bo())
return u},
bo(){var x,w,v=this,u=A.H(y.w,y.b)
u.k(0,"positive_prompt",v.a)
u.k(0,"negative_prompt",v.b)
u.k(0,"theme_tokens",v.c)
u.k(0,"lighting_tokens",v.d)
u.k(0,"style_tokens",v.e)
u.k(0,"decor_tokens",v.f)
u.k(0,"decor_elements",v.r)
u.k(0,"visual_keywords",v.w)
x=v.x
w=x!=null
if(w)u.k(0,"recommended_strength",x)
if(w)u.k(0,"strength",x)
x=v.y
if(x!=null)u.k(0,"cfg_scale",x)
x=v.z
if(x!=null)u.k(0,"steps",x)
x=v.Q
if(x!=null)u.k(0,"controlnet",x)
x=v.as
if(x!=null&&x.length!==0)u.k(0,"mode",x)
x=v.at
if(x!=null)u.k(0,"transformation_plan",x)
return u}}
var z=a.updateTypes([])
B.aym.prototype={
$1(d){var x
y.d.a(d)
x=d==null?C.bu:d
x=J.cg(x,new B.ayn(),y.w).cG(0,new B.ayo())
x=A.v(x,x.$ti.i("r.E"))
return x},
$S:221}
B.ayn.prototype={
$1(d){return C.e.m(A.h(d))},
$S:13}
B.ayo.prototype={
$1(d){return d.length!==0},
$S:3}
B.ayl.prototype={
$1(d){if(typeof d=="number")return d
return A.bD(A.h(d))},
$S:270}
B.ayj.prototype={
$1(d){if(typeof d=="number")return C.i.aJ(d)
return A.cm(A.h(d),null)},
$S:732}
B.ayk.prototype={
$1(d){if(y.B.b(d))return A.aD(d,y.w,y.b)
return null},
$S:252};(function inheritance(){var x=a.inherit,w=a.inheritMany
x(B.a4W,A.X)
w(A.eG,[B.aym,B.ayn,B.ayo,B.ayl,B.ayj,B.ayk])})()
var y={q:A.ac("a4W"),g:A.ac("co"),y:A.ac("S<e,@>"),B:A.ac("S<@,@>"),w:A.ac("e"),b:A.ac("@"),d:A.ac("a0<@>?")};(function constants(){G.Ih=new A.al(57531,"MaterialIcons",!1)})()};
(a=>{a["ag/TBS6oOHspESlpkSptTsEuZZw="]=a.current})($__dart_deferred_initializers__);