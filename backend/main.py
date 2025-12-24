"""
Charm AI Backend Server
=======================
FastAPI server that acts as middleware between Flutter app and AI services.
Securely handles OpenAI and Replicate API calls.

Deployment: Render (https://render.com)
"""

import os
import time
import asyncio
from datetime import datetime
from fastapi import FastAPI, HTTPException, status, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, Field
from typing import Optional, List, Literal
from openai import OpenAI, OpenAIError
import replicate
import json


# Initialize FastAPI app
app = FastAPI(
    title="Charm AI API",
    description="Backend API for Charm AI mobile application",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
)

# CORS Configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ============================================
# CLIENT INITIALIZATION
# ============================================

def get_openai_client() -> OpenAI:
    """Get OpenAI client with API key from environment"""
    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="OpenAI API key not configured. Set OPENAI_API_KEY environment variable."
        )
    return OpenAI(api_key=api_key)


def get_replicate_client():
    """Verify Replicate API token is configured"""
    api_token = os.getenv("REPLICATE_API_TOKEN")
    if not api_token:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Replicate API token not configured. Set REPLICATE_API_TOKEN environment variable."
        )
    # Replicate uses environment variable automatically
    return True


# ============================================
# PYDANTIC MODELS
# ============================================

class HealthResponse(BaseModel):
    """Health check response model"""
    status: str
    message: str
    timestamp: str
    version: str


class ChatMessage(BaseModel):
    """Individual chat message"""
    role: str = Field(..., description="Message role: 'user', 'assistant', or 'system'")
    content: str = Field(..., description="Message content")


class ChatRequest(BaseModel):
    """Chat completion request"""
    messages: List[ChatMessage] = Field(..., description="List of conversation messages")
    max_tokens: Optional[int] = Field(default=1000, ge=1, le=4096)
    temperature: Optional[float] = Field(default=0.7, ge=0.0, le=2.0)
    system_prompt: Optional[str] = Field(
        default="You are Charm AI, a helpful, friendly, and intelligent assistant. You provide clear, concise, and accurate responses. Be conversational and engaging while maintaining professionalism.",
        description="System prompt to set AI behavior"
    )


class ChatResponse(BaseModel):
    """Chat completion response"""
    message: str
    tokens_used: int
    model: str
    finish_reason: str


class ImageGenerationRequest(BaseModel):
    """Image generation request"""
    prompt: str = Field(..., min_length=1, max_length=2000, description="Image description prompt")
    negative_prompt: Optional[str] = Field(default="", description="What to avoid in the image")
    width: Optional[int] = Field(default=1024, ge=256, le=1440)
    height: Optional[int] = Field(default=1024, ge=256, le=1440)
    num_outputs: Optional[int] = Field(default=1, ge=1, le=4)
    model: Optional[str] = Field(default="flux-schnell", description="Model to use: flux-schnell, flux-dev, sdxl")
    guidance_scale: Optional[float] = Field(default=7.5, ge=1.0, le=20.0)
    num_inference_steps: Optional[int] = Field(default=28, ge=1, le=50)
    seed: Optional[int] = Field(default=None, description="Random seed for reproducibility")


class ImageGenerationResponse(BaseModel):
    """Image generation response"""
    images: List[str]
    generation_time: float
    model: str
    prompt: str


class GenerationStatusResponse(BaseModel):
    """Generation status response"""
    id: str
    status: str  # starting, processing, succeeded, failed, canceled
    output: Optional[List[str]] = None
    error: Optional[str] = None


# Available image models
IMAGE_MODELS = {
    "flux-schnell": "black-forest-labs/flux-schnell",
    "flux-dev": "black-forest-labs/flux-dev", 
    "sdxl": "stability-ai/sdxl:39ed52f2a78e934b3ba6e2a89f5b1c712de7dfea535525255b1aa35c5565e08b",
    "sdxl-lightning": "bytedance/sdxl-lightning-4step:5599ed30703defd1d160a25a63321b4dec97101d98b4674bcc56e41f62f35637",
}


# ============================================
# CHAT ENDPOINTS
# ============================================

@app.get("/", response_model=HealthResponse)
async def root():
    """Root endpoint - Welcome message"""
    return HealthResponse(
        status="online",
        message="Welcome to Charm AI API! 🚀",
        timestamp=datetime.utcnow().isoformat(),
        version="1.0.0"
    )


@app.get("/health", response_model=HealthResponse)
async def health_check():
    """Health check endpoint for monitoring"""
    return HealthResponse(
        status="healthy",
        message="Charm AI Backend is running smoothly",
        timestamp=datetime.utcnow().isoformat(),
        version="1.0.0"
    )


@app.post("/api/chat", response_model=ChatResponse)
async def chat_completion(request: ChatRequest):
    """Chat completion endpoint using OpenAI GPT-4o Mini"""
    try:
        client = get_openai_client()
        
        messages = [{"role": "system", "content": request.system_prompt}]
        for msg in request.messages:
            messages.append({"role": msg.role, "content": msg.content})
        
        response = client.chat.completions.create(
            model="gpt-4o-mini",
            messages=messages,
            max_tokens=request.max_tokens,
            temperature=request.temperature,
        )
        
        choice = response.choices[0]
        
        return ChatResponse(
            message=choice.message.content or "",
            tokens_used=response.usage.total_tokens if response.usage else 0,
            model=response.model,
            finish_reason=choice.finish_reason or "unknown"
        )
        
    except OpenAIError as e:
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=f"OpenAI API error: {str(e)}")
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=f"Internal server error: {str(e)}")


@app.post("/api/chat/stream")
async def chat_completion_stream(request: ChatRequest):
    """Streaming chat completion endpoint"""
    try:
        client = get_openai_client()
        
        messages = [{"role": "system", "content": request.system_prompt}]
        for msg in request.messages:
            messages.append({"role": msg.role, "content": msg.content})
        
        async def generate():
            try:
                stream = client.chat.completions.create(
                    model="gpt-4o-mini",
                    messages=messages,
                    max_tokens=request.max_tokens,
                    temperature=request.temperature,
                    stream=True,
                )
                
                for chunk in stream:
                    if chunk.choices[0].delta.content:
                        data = {"content": chunk.choices[0].delta.content, "is_complete": False}
                        yield f"data: {json.dumps(data)}\n\n"
                
                yield f"data: {json.dumps({'content': '', 'is_complete': True})}\n\n"
                
            except OpenAIError as e:
                yield f"data: {json.dumps({'error': str(e), 'is_complete': True})}\n\n"
        
        return StreamingResponse(generate(), media_type="text/event-stream", headers={"Cache-Control": "no-cache", "Connection": "keep-alive"})
        
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=f"Failed to start stream: {str(e)}")


# ============================================
# IMAGE GENERATION ENDPOINTS
# ============================================

@app.get("/api/generate/models")
async def get_available_models():
    """Get list of available image generation models"""
    return {
        "models": [
            {"id": "flux-schnell", "name": "Flux Schnell", "description": "Fast, high-quality images", "speed": "fast"},
            {"id": "flux-dev", "name": "Flux Dev", "description": "Higher quality, slower", "speed": "medium"},
            {"id": "sdxl", "name": "SDXL", "description": "Stable Diffusion XL", "speed": "medium"},
            {"id": "sdxl-lightning", "name": "SDXL Lightning", "description": "Fast SDXL variant", "speed": "fast"},
        ]
    }


@app.post("/api/generate/image", response_model=ImageGenerationResponse)
async def generate_image(request: ImageGenerationRequest):
    """
    Generate image using Replicate models
    
    Supports multiple models:
    - flux-schnell: Fast, high-quality (recommended)
    - flux-dev: Higher quality, slower
    - sdxl: Stable Diffusion XL
    - sdxl-lightning: Fast SDXL variant
    """
    try:
        get_replicate_client()
        
        start_time = time.time()
        
        # Get model identifier
        model_id = IMAGE_MODELS.get(request.model, IMAGE_MODELS["flux-schnell"])
        
        # Prepare input based on model
        if request.model in ["flux-schnell", "flux-dev"]:
            # Flux models
            input_params = {
                "prompt": request.prompt,
                "num_outputs": request.num_outputs,
                "aspect_ratio": _get_aspect_ratio(request.width, request.height),
                "output_format": "webp",
                "output_quality": 90,
            }
            if request.seed:
                input_params["seed"] = request.seed
                
        else:
            # SDXL models
            input_params = {
                "prompt": request.prompt,
                "negative_prompt": request.negative_prompt or "ugly, blurry, low quality, distorted",
                "width": request.width,
                "height": request.height,
                "num_outputs": request.num_outputs,
                "guidance_scale": request.guidance_scale,
                "num_inference_steps": request.num_inference_steps,
            }
            if request.seed:
                input_params["seed"] = request.seed
        
        # Run the model
        output = replicate.run(model_id, input=input_params)
        
        # Process output
        images = []
        if isinstance(output, list):
            images = [str(url) for url in output]
        elif hasattr(output, '__iter__'):
            images = [str(url) for url in output]
        else:
            images = [str(output)]
        
        generation_time = time.time() - start_time
        
        return ImageGenerationResponse(
            images=images,
            generation_time=round(generation_time, 2),
            model=request.model,
            prompt=request.prompt
        )
        
    except replicate.exceptions.ReplicateError as e:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Replicate API error: {str(e)}"
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Image generation failed: {str(e)}"
        )


@app.post("/api/generate/image/async")
async def generate_image_async(request: ImageGenerationRequest):
    """
    Start async image generation (returns prediction ID)
    Use /api/generate/status/{prediction_id} to check progress
    """
    try:
        get_replicate_client()
        
        model_id = IMAGE_MODELS.get(request.model, IMAGE_MODELS["flux-schnell"])
        
        # Prepare input
        if request.model in ["flux-schnell", "flux-dev"]:
            input_params = {
                "prompt": request.prompt,
                "num_outputs": request.num_outputs,
                "aspect_ratio": _get_aspect_ratio(request.width, request.height),
                "output_format": "webp",
            }
        else:
            input_params = {
                "prompt": request.prompt,
                "negative_prompt": request.negative_prompt or "ugly, blurry, low quality",
                "width": request.width,
                "height": request.height,
                "num_outputs": request.num_outputs,
                "guidance_scale": request.guidance_scale,
            }
        
        # Create prediction
        model = replicate.models.get(model_id.split(":")[0] if ":" in model_id else model_id)
        version = model.latest_version if not ":" in model_id else None
        
        prediction = replicate.predictions.create(
            version=version or model_id.split(":")[1],
            input=input_params
        )
        
        return {
            "prediction_id": prediction.id,
            "status": prediction.status,
            "model": request.model
        }
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to start generation: {str(e)}"
        )


@app.get("/api/generate/status/{prediction_id}", response_model=GenerationStatusResponse)
async def get_generation_status(prediction_id: str):
    """Get status of async image generation"""
    try:
        get_replicate_client()
        
        prediction = replicate.predictions.get(prediction_id)
        
        output = None
        if prediction.output:
            if isinstance(prediction.output, list):
                output = [str(url) for url in prediction.output]
            else:
                output = [str(prediction.output)]
        
        return GenerationStatusResponse(
            id=prediction.id,
            status=prediction.status,
            output=output,
            error=str(prediction.error) if prediction.error else None
        )
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get status: {str(e)}"
        )


def _get_aspect_ratio(width: int, height: int) -> str:
    """Convert dimensions to aspect ratio string for Flux models"""
    ratio = width / height
    
    if ratio >= 1.7:
        return "16:9"
    elif ratio >= 1.4:
        return "3:2"
    elif ratio >= 1.2:
        return "4:3"
    elif ratio >= 0.9:
        return "1:1"
    elif ratio >= 0.7:
        return "3:4"
    elif ratio >= 0.6:
        return "2:3"
    else:
        return "9:16"


# ============================================
# ERROR HANDLERS
# ============================================

@app.exception_handler(HTTPException)
async def http_exception_handler(request, exc):
    return {"error": exc.detail, "status_code": exc.status_code, "timestamp": datetime.utcnow().isoformat()}


# ============================================
# RUN SERVER
# ============================================

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
