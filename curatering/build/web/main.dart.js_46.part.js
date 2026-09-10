((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,A,C,G,E,D={aLc:function aLc(){}},B,F
J=c[1]
A=c[0]
C=c[2]
G=c[55]
E=c[53]
D=a.updateHolder(c[12],D)
B=c[56]
F=c[45]
D.aLc.prototype={
Ey(d){return this.ayS(d)},
ayS(d){var x=0,w=A.l(y.i),v,u,t,s,r,q
var $async$Ey=A.m(function(e,f){if(e===1)return A.i(f,w)
for(;;)switch(x){case 0:x=3
return A.d(A.eF(A.bE("https://curatering.up.railway.app/api/online-inquiries",0,null),C.a4.cr(d,null),null,F.mb).cM(G.fh),$async$Ey)
case 3:q=f
if(q.b<200||q.b>=300){u="Failed to submit online inquiry ("+q.b+")"
try{s=q
t=C.a4.bu(A.cF(A.cE(s.e)).ba(s.w),null)
if(y.l.b(t)&&t.h(0,"message")!=null)u=J.w(t.h(0,"message"))}catch(p){}throw A.p(A.ar2(u,q.b))}s=q
if(C.e.m(A.cF(A.cE(s.e)).ba(s.w)).length===0){v=C.iz
x=1
break}s=q
t=C.a4.bu(A.cF(A.cE(s.e)).ba(s.w),null)
v=y.l.b(t)?A.aD(t,y.g,y.b):C.iz
x=1
break
case 1:return A.j(v,w)}})
return A.k($async$Ey,w)},
a4Z(d,e,f){return this.bkp(d,e,f)},
bkp(d,e,f){var x=0,w=A.l(y.i),v
var $async$a4Z=A.m(function(g,h){if(g===1)return A.i(h,w)
for(;;)switch(x){case 0:v=$.bN().ea("/api/public/events/theme-design/yolo-sam-infer",A.Q(["imageBase64",d,"confidenceThreshold",0.25,"maxDetections",f,"maskFormat",e],y.g,y.b)).cM(B.h8)
x=1
break
case 1:return A.j(v,w)}})
return A.k($async$a4Z,w)},
Mk(d,e,f){return this.aE9(d,e,f)},
aE9(d,e,f){var x=0,w=A.l(y.i),v
var $async$Mk=A.m(function(g,h){if(g===1)return A.i(h,w)
for(;;)switch(x){case 0:v=$.bN().ea("/api/public/events/theme-design/swap-colors",A.Q(["imageBase64",e,"masks",f,"edits",d],y.g,y.b)).cM(B.h8)
x=1
break
case 1:return A.j(v,w)}})
return A.k($async$Mk,w)},
Ws(d,e,f,g,h,i,j,k){return this.axA(d,e,f,g,h,i,j,k)},
axA(d,e,f,g,h,i,j,k){var x=0,w=A.l(y.i),v
var $async$Ws=A.m(function(l,m){if(l===1)return A.i(m,w)
for(;;)switch(x){case 0:v=$.bN().ea("/api/public/events/theme-design/theme-search",A.Q(["eventTitle",e,"eventType",f,"formalityLevel",g,"prompt",j,"baseImageUrl",d,"tags",k,"page",h,"perPage",i],y.g,y.b)).cM(B.h8)
x=1
break
case 1:return A.j(v,w)}})
return A.k($async$Ws,w)},
a4h(d){return this.bi8(d)},
bi8(d){var x=0,w=A.l(y.i),v
var $async$a4h=A.m(function(e,f){if(e===1)return A.i(f,w)
for(;;)switch(x){case 0:v=$.bN().ea("/api/public/events/theme-design/extract-objects",A.Q(["imagesBase64",d,"confidenceThreshold",0.25,"maxDetections",20],y.g,y.b)).cM(B.h8)
x=1
break
case 1:return A.j(v,w)}})
return A.k($async$a4h,w)},
a2u(d){return this.bda(d)},
bda(d){var x=0,w=A.l(y.i),v
var $async$a2u=A.m(function(e,f){if(e===1)return A.i(f,w)
for(;;)switch(x){case 0:v=$.bN().ea("/api/public/events/theme-design/analyze-base",A.Q(["baseImageBase64",d],y.g,y.b)).cM(B.h8)
x=1
break
case 1:return A.j(v,w)}})
return A.k($async$a2u,w)},
a2F(d,e){return this.bdw(d,e)},
bdw(d,e){var x=0,w=A.l(y.i),v
var $async$a2F=A.m(function(f,g){if(f===1)return A.i(g,w)
for(;;)switch(x){case 0:v=$.bN().ea("/api/public/events/theme-design/auto-place",A.Q(["freeSpaces",d,"objects",e],y.g,y.b)).cM(B.h8)
x=1
break
case 1:return A.j(v,w)}})
return A.k($async$a2F,w)},
a6M(d,e){return this.bpm(d,e)},
bpm(d,e){var x=0,w=A.l(y.i),v
var $async$a6M=A.m(function(f,g){if(f===1)return A.i(g,w)
for(;;)switch(x){case 0:v=$.bN().ea("/api/public/events/theme-design/render-composite",A.Q(["baseImageBase64",d,"objects",e],y.g,y.b)).cM(B.h8)
x=1
break
case 1:return A.j(v,w)}})
return A.k($async$a6M,w)}}
var z=a.updateTypes([]);(function inheritance(){var x=a.inherit
x(D.aLc,A.X)})()
var y={i:A.ac("S<e,@>"),l:A.ac("S<@,@>"),g:A.ac("e"),b:A.ac("@")};(function constants(){B.h8=new A.bx(18e7)
B.J8=new A.aj(E.IP,null,null,null,null)
B.Im=new A.al(57785,"MaterialIcons",!1)
B.zd=new A.aj(E.nS,null,null,null,null)
B.Iv=new A.al(58460,"MaterialIcons",!0)
B.C9=new A.a_(1/0,48)
B.CL=new A.G(!0,null,null,null,null,null,13,C.ax,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null)
B.CR=new A.G(!0,F.cL,null,null,null,null,20,C.a5,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null)
B.CV=new A.G(!0,null,null,null,null,null,12,C.ax,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null)
B.a3b=new A.o("Back",null,null,null,null,null,null,null,null,null,null)})();(function lazyInitializers(){var x=a.lazyFinal
x($,"cI3","tP",()=>new D.aLc())})()};
(a=>{a["8wI0XfcLVSTCO7KyBNiuXwGm65Y="]=a.current})($__dart_deferred_initializers__);